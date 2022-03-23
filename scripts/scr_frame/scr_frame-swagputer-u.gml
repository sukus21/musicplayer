function frame_powtab_create() {
	var _arr = array_create(8207);
	for(var i = 0; i < 8207; i++) {
		_arr[i] = power(i, 4.0 / 3.0);
	}
	return _arr;
}

function frame_t() constructor {
	header = 0;
	sideinfo = noone;
	maindata = noone;
	mainbits = noone;
	
	store = [array_create(32), array_create(32)];
	v_vec = [array_create(1024), array_create(1024)];
	
	for(var i = 0; i < 32; i++) {
		store[0][i] = array_create(18);
		store[1][i] = array_create(18);
	}
}

function frame_read(p_buffer, p_previous) {
	
	//Get frame header
	var _header = frameheader_read(p_buffer);
	if(is_string(_header))
		return _header;
	
	//Is this thing protected?
	if(frameheader_protectionbit(_header) == 0) {
		//TODO: protected
		show_debug_message("TODO: Protection bit set");
	}
	
	//Discard version 2.5
	if(frameheader_id(_header) == VERSION.V2_5)
		return "mp3: MPEG version 2.5 is not supported";
	
	//ONLY mp3 supported
	if(frameheader_mpeglayer(_header) != MPEGLAYER.L3)
		return "mp3: only layer3 (want " + string(MPEGLAYER.L3) + "; got " + string(frameheader_mpeglayer(_header)) + ") is supported";
	
	//Get sideinfo
	var _sideinfo = sideinfo_read(p_buffer, _header);
	if(is_string(_sideinfo))
		return _sideinfo;
	
	//uh
	var _prevm = noone;
	if(p_previous != noone)
		_prevm = p_previous.mainbits;
	
	//Read main data
	var _res = maindata_read(p_buffer, _prevm, _header, _sideinfo);
	if(is_string(_res))
		return _res;
	
	//Create frame element
	var _frame = new frame_t();
	_frame.header = _header;
	_frame.sideinfo = _sideinfo;
	_frame.maindata = _res[0];
	_frame.mainbits = _res[1];
	
	//Copy these from previous frame
	if(p_previous != noone) {
		_frame.store = p_previous.store;
		_frame.v_vec = p_previous.v_vec;
	}
	
	//Return new frame
	return _frame;
}

function frame_decode(p_frame) {
	
	//Create a buffer and get channel count (again...)
	var _out = buffer_create(frameheader_bytesperframe(p_frame.header), buffer_grow, 2);
	var _channels = frameheader_channelcount(p_frame.header);
	
	//Meat and potatoes
	for(var gr = 0; gr < frameheader_granules(p_frame.header); gr++) {
		for(var ch = 0; ch < _channels; ch++) {
			frame_requantize(p_frame, gr, ch);
			frame_reorder(p_frame, gr, ch);
		}
		
		frame_stereo(p_frame, gr);
		var _tell = buffer_tell(_out);
		for(var ch = 0; ch < _channels; ch++) {
			buffer_seek(_out, buffer_seek_start, _tell);
			frame_antialias(p_frame, gr, ch);
			frame_hybrid_synthesis(p_frame, gr, ch);
			frame_frequency_inversion(p_frame, gr, ch);
			frame_subband_synthesis(p_frame, gr, ch, _out);
		}
	}
	
	//Return finished buffer :)
	return _out;
}

//Helper function
function frame_sfb_indexarray(p_frame, p_header) {
	
	static band_indices = [
		[ // MPEG 1
			[ // Layer 3
				[0, 4, 8, 12, 16, 20, 24, 30, 36, 44, 52, 62, 74, 90, 110, 134, 162, 196, 238, 288, 342, 418, 576],
				[0, 4, 8, 12, 16, 22, 30, 40, 52, 66, 84, 106, 136, 192],
			],
			[ // Layer 2
				[0, 4, 8, 12, 16, 20, 24, 30, 36, 42, 50, 60, 72, 88, 106, 128, 156, 190, 230, 276, 330, 384, 576],
				[0, 4, 8, 12, 16, 22, 28, 38, 50, 64, 80, 100, 126, 192],
			],
			[ // Layer 1
				[0, 4, 8, 12, 16, 20, 24, 30, 36, 44, 54, 66, 82, 102, 126, 156, 194, 240, 296, 364, 448, 550, 576],
				[0, 4, 8, 12, 16, 22, 30, 42, 58, 78, 104, 138, 180, 192],
			],
		],
		[ // MPEG 2
			[ // Layer 3
				[0, 6, 12, 18, 24, 30, 36, 44, 54, 66, 80, 96, 116, 140, 168, 200, 238, 284, 336, 396, 464, 522, 576],
				[0, 4, 8, 12, 18, 24, 32, 42, 56, 74, 100, 132, 174, 192],
			],
			[ // Layer 2
				[0, 6, 12, 18, 24, 30, 36, 44, 54, 66, 80, 96, 114, 136, 162, 194, 232, 278, 332, 394, 464, 540, 576],
				[0, 4, 8, 12, 18, 26, 36, 48, 62, 80, 104, 136, 180, 192],
			],
			[ // Layer 1
				[0, 6, 12, 18, 24, 30, 36, 44, 54, 66, 80, 96, 116, 140, 168, 200, 238, 284, 336, 396, 464, 522, 576],
				[0, 4, 8, 12, 18, 26, 36, 48, 62, 80, 104, 134, 174, 192],
			],
		]
	];
	
	var _sfreq = frameheader_samplingfrequency(p_header);
	var _lfreq = frameheader_samplingfrequency_low(p_header);
	
	return band_indices[_lfreq][_sfreq];
}

//Pre-stereo handling
function frame_requantize_long(p_frame, gr, ch, p_pos, p_sfb) {
	
	static pretab = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 3, 3, 3, 2, 0];
	static powtab = frame_powtab_create();
	
	var _multiplier = 0.5;
	if(p_frame.sideinfo.scalefac_scale[gr][ch] != 0)
		_multiplier = 1;
	
	var _xpt = p_frame.sideinfo.preflag[gr][ch] * pretab[p_sfb];
	var _index = -(_multiplier * (p_frame.maindata.scalefac_l[gr][ch][p_sfb] + _xpt)) + 0.25 * (p_frame.sideinfo.global_gain[gr][ch] - 210);
	var _temp1 = power(2, _index);
	var _temp2 = powtab[p_frame.maindata.is[gr][ch][p_pos]];
	if(p_frame.maindata.is[gr][ch][p_pos] < 0.0)
		_temp2 = -_temp2;
	
	p_frame.maindata.is[gr][ch][p_pos] = _temp1 * _temp2;
}
function frame_requantize_short(p_frame, gr, ch, p_pos, p_sfb, p_win) {
	
	static powtab = frame_powtab_create();
	
	var _multiplier = 0.5;
	if(p_frame.sideinfo.scalefac_scale[gr][ch] != 0)
		_multiplier = 1;
	
	var _index = -(_multiplier * p_frame.maindata.scalefac_s[gr][ch][p_sfb][p_win]) + 0.25*(p_frame.sideinfo.global_gain[gr][ch] - 210.0 - 8.0 * p_frame.sideinfo.subblock_gain[gr][ch][p_win]);
	var _temp1 = power(2, _index);
	var _temp2 = powtab[p_frame.maindata.is[gr][ch][p_pos]];
	
	p_frame.maindata.is[gr][ch][p_pos] = _temp1 * _temp2;
}
function frame_requantize(p_frame, gr, ch) {

	var _res = frame_sfb_indexarray(p_frame, p_frame.header);
	var _bandlong = _res[SFBINDEX.LONG];
	var _bandshort = _res[SFBINDEX.SHORT];
	
	//What type of block is this?
	if(p_frame.sideinfo.win_switch_flag[gr][ch] == 1 and p_frame.sideinfo.block_type[gr][ch] == 2) {
		
		//Mixed block
		if(p_frame.sideinfo.mixed_block_flag[gr][ch] != 0) {
			
			//Read long block
			var _sfb = 0;
			var _sfb_next = _bandlong[_sfb+1];
			for(var i = 0; i < 36; i++) {
				if(i == _sfb_next) {
					_sfb++;
					_sfb_next = _bandlong[_sfb+1];
				}
				frame_requantize_long(p_frame, gr, ch, i, _sfb);
			}
			
			//Read short block
			_sfb = 3;
			_sfb_next = _bandshort[_sfb+1];
			var _winlen = _bandshort[_sfb+1] - _bandshort[_sfb];
			for(var i = 36; i < p_frame.sideinfo.count1[gr][ch]; ) {
				if(i == _sfb_next) {
					_sfb++;
					_sfb_next = _bandshort[_sfb+1] * 3;
					_winlen = _bandshort[_sfb+1] - _bandshort[_sfb];
				}
				
				for(var _win = 0; _win < 3; _win++) {
					for(var j = 0; j < _winlen; j++) {
						frame_requantize_short(p_frame, gr, ch, i, _sfb, _win);
						i++;
					}
				}
			}
		}
		
		//Unmixed short block
		else {
			var _sfb = 0;
			var _sfb_next = _bandshort[_sfb+1];
			var _winlen = _bandshort[_sfb+1] - _bandshort[_sfb];
			for(var i = 0; i < p_frame.sideinfo.count1[gr][ch]; ) {
				if(i == _sfb_next) {
					_sfb++;
					_sfb_next = _bandshort[_sfb+1] * 3;
					_winlen = _bandshort[_sfb+1] - _bandshort[_sfb];
				}
				
				for(var _win = 0; _win < 3; _win++) {
					for(var j = 0; j < _winlen; j++) {
						frame_requantize_short(p_frame, gr, ch, i, _sfb, _win);
						i++;
					}
				}
			}
		}
	}
	
	//Unmixed long block
	else {
		var _sfb = 0;
		var _sfb_next = _bandlong[_sfb+1];
		for(var i = 0; i < p_frame.sideinfo.count1[gr][ch]; i++) {
			if(i == _sfb_next) {
				_sfb++;
				_sfb_next = _bandlong[_sfb+1];
			}
			frame_requantize_long(p_frame, gr, ch, i, _sfb);
		}
	}
}
function frame_reorder(p_frame, gr, ch) {
	
	var _reorder = array_create(SAMPLES_PER_GRANULE);
	var _bandshort = frame_sfb_indexarray(p_frame, p_frame.header)[SFBINDEX.SHORT];
	
	//Only reorder short blocks
	if(p_frame.sideinfo.win_switch_flag[gr][ch] == 1 and p_frame.sideinfo.block_type[gr][ch] == 2) {
		
		var _sfb = 0;
		if(p_frame.sideinfo.mixed_block_flag[gr][ch] != 0)
			_sfb += 3;
	
		var _sfb_next = _bandshort[_sfb+1] * 3;
		var _winlen = _bandshort[_sfb+1] - _bandshort[_sfb];
	
		for(var i = _sfb == 0 ? 0 : 36; i < SAMPLES_PER_GRANULE; ) {
		
			if(i == _sfb_next) {
			
				//Copy reordered data back
				var j = _bandshort[_sfb] * 3;
				array_copy(p_frame.maindata.is[gr][ch], j, _reorder, 0, _winlen*3);
			
				if(i >= p_frame.sideinfo.count1[gr][ch])
					return;
			
				_sfb++;
				_sfb_next = _bandshort[_sfb+1] * 3;
				_winlen = _bandshort[_sfb+1] - _bandshort[_sfb];
			}
		
			//Actually reorder data
			for(var _win = 0; _win < 3; _win++) {
				for(var j = 0; j < _winlen; j++) {
					_reorder[j*3 + _win] = p_frame.maindata.is[gr][ch][i];
					i++;
				}
			}
		}
		
		//Copy reordered data back
		array_copy(p_frame.maindata.is[gr][ch], _bandshort[12] * 3, _reorder, 0, _winlen*3);
	}
}

//Stereo handling
function frame_stereo_long(p_frame, gr, p_sfb) {
	
	static is_ratios = [0.000000, 0.267949, 0.577350, 1.000000, 1.732051, 3.732051];
	
	var _ratio_l = 0;
	var _ratio_r = 0;
	var _ispos = p_frame.maindata.scalefac_l[gr][0][p_sfb];
	
	if(_ispos < 7) {
		var _bandlong = frame_sfb_indexarray(p_frame, p_frame.header)[SFBINDEX.LONG];
		var _sfb_start = _bandlong[p_sfb];
		var _sfb_stop = _bandlong[p_sfb+1];
		
		if(_ispos == 6)
			_ratio_l = 1;
		else {
			_ratio_l = is_ratios[_ispos] / (1 + is_ratios[_ispos]);
			_ratio_r = 1 / (1 + is_ratios[_ispos]);
		}
		
		//Decode samples
		for(var i = _sfb_start; i < _sfb_stop; i++) {
			p_frame.maindata.is[gr][0][i] *= _ratio_l;
			p_frame.maindata.is[gr][1][i] *= _ratio_r;
		}
	}
}
function frame_stereo_short(p_frame, gr, p_sfb) {
	
	static is_ratios = [0.000000, 0.267949, 0.577350, 1.000000, 1.732051, 3.732051];
	
	var _ratio_l = 0;
	var _ratio_r = 0;
	var _ispos = p_frame.maindata.scalefac_l[gr][0][p_sfb];
	
	if(_ispos < 7) {
		var _bandshort = frame_sfb_indexarray(p_frame, p_frame.header)[SFBINDEX.SHORT];
		var _winlen = _bandshort[p_sfb+1] - _bandshort[p_sfb];
		
		for(var _win = 0; _win < 3; _win++) {
			
			var _ispos = p_frame.maindata.scalefac_s[gr][0][p_sfb][_win];
			if(_ispos < 7) {
				var _sfb_start = _bandshort[p_sfb]*3 + _winlen*_win;
				var _sfb_stop = _sfb_start + _winlen;
		
				if(_ispos == 6)
					_ratio_l = 1;
				else {
					_ratio_l = is_ratios[_ispos] / (1 + is_ratios[_ispos]);
					_ratio_r = 1 / (1 + is_ratios[_ispos]);
				}
		
				//Decode samples
				for(var i = _sfb_start; i < _sfb_stop; i++) {
					p_frame.maindata.is[gr][0][i] *= _ratio_l;
					p_frame.maindata.is[gr][1][i] *= _ratio_r;
				}
			}
		}
	}
}
function frame_stereo(p_frame, gr) {
	
	static inv_sqrt2 = sqrt(2) / 2;
	
	//Joint stereo or something
	if(frameheader_use_msstereo(p_frame.header)) {
		
		//How many lines to transform?
		var _maxpos = max(p_frame.sideinfo.count1[gr][0] > p_frame.sideinfo.count1[gr][1]);
		
		//Transform the heck out of this thing
		for(var i = 0; i < _maxpos; i++) {
			var _left = (p_frame.maindata.is[gr][0][i] + p_frame.maindata.is[gr][1][i]) * inv_sqrt2;
			var _right = (p_frame.maindata.is[gr][0][i] - p_frame.maindata.is[gr][1][i]) * inv_sqrt2;
			p_frame.maindata.is[gr][0][i] = _left;
			p_frame.maindata.is[gr][1][i] = _right;
		}
	}
	
	if(frameheader_use_intensitystereo(p_frame.header)) {
		
		var _res = frame_sfb_indexarray(p_frame, p_frame.header);
		var _bandlong = _res[SFBINDEX.LONG];
		var _bandshort = _res[SFBINDEX.SHORT];
		
		//Mixed or short block?
		if(p_frame.sideinfo.win_switch_flag[gr][0] == 1 and p_frame.sideinfo.block_type[gr][0] == 2) {
			
			if(p_frame.sideinfo.mixed_block_flag[gr][0] != 0) {
				
				//Long banks first
				for(var sfb = 0; sfb < 8; sfb++) {
					if(_bandlong[sfb] >= p_frame.sideinfo.count1[gr][1])
						frame_stereo_long(p_frame, gr, sfb);
				}
				
				//Short bands next
				for(var sfb = 3; sfb < 12; sfb++) {
					if(_bandshort[sfb] * 3 >= p_frame.sideinfo.count1[gr][1])
						frame_stereo_short(p_frame, gr, sfb);
				}
			}
			
			//Only short blocks
			else {
				for(var sfb = 0; sfb < 12; sfb++) {
					if(_bandshort[sfb] * 3 >= p_frame.sideinfo.count1[gr][1])
						frame_stereo_short(p_frame, gr, sfb);
				}
			}
		}
		
		//Only long blocks
		else {
			for(var sfb = 0; sfb < 21; sfb++) {
				if(_bandlong[sfb] >= p_frame.sideinfo.count1[gr][1])
					frame_stereo_long(p_frame, gr, sfb);
			}
		}
	}
}

//Post-stereo handling
function frame_antialias(p_frame, gr, ch) {
	
	static cs = [0.857493, 0.881742, 0.949629, 0.983315, 0.995518, 0.999161, 0.999899, 0.999993];
	static ca = [-0.514496, -0.471732, -0.313377, -0.181913, -0.094574, -0.040966, -0.014199, -0.003700];
	
	//Skip short blocks
	if(
		p_frame.sideinfo.win_switch_flag[gr][ch] == 1 
		and p_frame.sideinfo.block_type[gr][ch] == 2 
		and p_frame.sideinfo.mixed_block_flag[gr][ch] == 0
	)
		return;
	
	//Set a limit
	var _limit = 32;
	if(
		p_frame.sideinfo.win_switch_flag[gr][ch] == 1 
		and p_frame.sideinfo.block_type[gr][ch] == 2 
		and p_frame.sideinfo.mixed_block_flag[gr][ch] == 1
	)
		_limit = 2;
	
	//Do anti aliasing
	for(var i = 1; i < _limit; i++) {
		for(var j = 0; j < 8; j++) {
			var _li = 18 * i - 1 - j;
			var _ui = 18 * i + j;
			
			var _lb = p_frame.maindata.is[gr][ch][_li] * cs[j] - p_frame.maindata.is[gr][ch][_ui] * ca[j];
			var _ub = p_frame.maindata.is[gr][ch][_li] * ca[j] - p_frame.maindata.is[gr][ch][_ui] * cs[j];
			
			p_frame.maindata.is[gr][ch][_li] = _lb;
			p_frame.maindata.is[gr][ch][_ui] = _ub;
		}
	}
}
function frame_hybrid_synthesis(p_frame, gr, ch) {
	
	//Go through all sub bands
	for(var i = 0; i < 32; i++) {
		
		//Block type?
		var _type = p_frame.sideinfo.block_type[gr][ch];
		if(p_frame.sideinfo.win_switch_flag[gr][ch] == 1 and p_frame.sideinfo.mixed_block_flag[gr][ch] == 1 and i < 2)
			_type = 0;
		
		var _in = array_create(18);
		for(var j = 0; j < 18; j++)
			_in[j] = p_frame.maindata.is[gr][ch][i*18+j];
		
		var _out = imdct_win(_in, _type);
		
		//Uh
		for(var j = 0; j < 18; j++) {
			p_frame.maindata.is[gr][ch][i*18 + j] = _out[j] + p_frame.store[ch][i][j];
			p_frame.store[ch][i][j] = _out[j + 18];
		}
	}
}
function frame_frequency_inversion(p_frame, gr, ch) {
	for(var i = 1; i < 32; i += 2)
		for(var j = 1; j < 18; j += 2)
			p_frame.maindata.is[gr][ch][i*18+j] = -p_frame.maindata.is[gr][ch][i*18+j];
}
function frame_subband_synthesis(p_frame, gr, ch, p_out) {
	
	//Static function variables
	static synth_dtbl = frame_init_synth_dtbl();
	static synth_nwin = frame_init_synth_nwin();
	
	//Buffers and variables
	var _uvec = array_create(512);
	var _svec = array_create(32);
	var _channels = frameheader_channelcount(p_frame.header);
	
	for(var ss = 0; ss < 18; ss++) {
		
		//Shift data (for some reason)
		array_copy(p_frame.v_vec[ch], 64, p_frame.v_vec[ch], 0, 1024-64);
		
		//Copy the next 32 samples to temporary buffer
		for(var i = 0; i < 32; i++)
			_svec[i] = p_frame.maindata.is[gr][ch][i*18+ss];
		
		//Matrix multiplication
		for(var i = 0; i < 64; i++) {
			var _sum = 0;
			for(var j = 0; j < 32; j++)
				_sum += synth_nwin[i][j] * _svec[j];
			
			p_frame.v_vec[ch][i] = _sum;
		}
		
		//Copy data to uvec
		for(var i = 0; i < 512; i += 64) {
			array_copy(_uvec, i, p_frame.v_vec[ch], i << 1, 32);	
			array_copy(_uvec, i+32, p_frame.v_vec[ch], (i << 1) + 96, 32);
		}
		
		//Windowing??
		for(var i = 0; i < 512; i++)
			_uvec[i] *= synth_dtbl[i];
		
		//Calculate 32 samples
		for(var i = 0; i < 32; i++) {
			
			//Get sum of uvec array
			var _sum = 0;
			for(var j = 0; j < 512; j += 32)
				_sum += _uvec[i+j];
			
			var _sample = clamp(floor(_sum * 32767), -32767, 32767);
			
			//Duplicate output
			if(_channels == 1) {
				buffer_write(p_out, buffer_s16, _sample);	
				buffer_write(p_out, buffer_s16, _sample);	
			}
			
			//Write channel 1 (bytes 0 and 1)
			else if(ch == 0) {
				buffer_write(p_out, buffer_s16, _sample);
				buffer_seek(p_out, buffer_seek_relative, 2);
			}
			
			//Write channel 2 (bytes 2 and 3)
			else {
				buffer_seek(p_out, buffer_seek_relative, 2);
				buffer_write(p_out, buffer_s16, _sample);
			}
		}
	}
}

function frame_init_synth_dtbl() {
	return [
		0.000000000, -0.000015259, -0.000015259, -0.000015259,
		-0.000015259, -0.000015259, -0.000015259, -0.000030518,
		-0.000030518, -0.000030518, -0.000030518, -0.000045776,
		-0.000045776, -0.000061035, -0.000061035, -0.000076294,
		-0.000076294, -0.000091553, -0.000106812, -0.000106812,
		-0.000122070, -0.000137329, -0.000152588, -0.000167847,
		-0.000198364, -0.000213623, -0.000244141, -0.000259399,
		-0.000289917, -0.000320435, -0.000366211, -0.000396729,
		-0.000442505, -0.000473022, -0.000534058, -0.000579834,
		-0.000625610, -0.000686646, -0.000747681, -0.000808716,
		-0.000885010, -0.000961304, -0.001037598, -0.001113892,
		-0.001205444, -0.001296997, -0.001388550, -0.001480103,
		-0.001586914, -0.001693726, -0.001785278, -0.001907349,
		-0.002014160, -0.002120972, -0.002243042, -0.002349854,
		-0.002456665, -0.002578735, -0.002685547, -0.002792358,
		-0.002899170, -0.002990723, -0.003082275, -0.003173828,
		0.003250122, 0.003326416, 0.003387451, 0.003433228,
		0.003463745, 0.003479004, 0.003479004, 0.003463745,
		0.003417969, 0.003372192, 0.003280640, 0.003173828,
		0.003051758, 0.002883911, 0.002700806, 0.002487183,
		0.002227783, 0.001937866, 0.001617432, 0.001266479,
		0.000869751, 0.000442505, -0.000030518, -0.000549316,
		-0.001098633, -0.001693726, -0.002334595, -0.003005981,
		-0.003723145, -0.004486084, -0.005294800, -0.006118774,
		-0.007003784, -0.007919312, -0.008865356, -0.009841919,
		-0.010848999, -0.011886597, -0.012939453, -0.014022827,
		-0.015121460, -0.016235352, -0.017349243, -0.018463135,
		-0.019577026, -0.020690918, -0.021789551, -0.022857666,
		-0.023910522, -0.024932861, -0.025909424, -0.026840210,
		-0.027725220, -0.028533936, -0.029281616, -0.029937744,
		-0.030532837, -0.031005859, -0.031387329, -0.031661987,
		-0.031814575, -0.031845093, -0.031738281, -0.031478882,
		0.031082153, 0.030517578, 0.029785156, 0.028884888,
		0.027801514, 0.026535034, 0.025085449, 0.023422241,
		0.021575928, 0.019531250, 0.017257690, 0.014801025,
		0.012115479, 0.009231567, 0.006134033, 0.002822876,
		-0.000686646, -0.004394531, -0.008316040, -0.012420654,
		-0.016708374, -0.021179199, -0.025817871, -0.030609131,
		-0.035552979, -0.040634155, -0.045837402, -0.051132202,
		-0.056533813, -0.061996460, -0.067520142, -0.073059082,
		-0.078628540, -0.084182739, -0.089706421, -0.095169067,
		-0.100540161, -0.105819702, -0.110946655, -0.115921021,
		-0.120697021, -0.125259399, -0.129562378, -0.133590698,
		-0.137298584, -0.140670776, -0.143676758, -0.146255493,
		-0.148422241, -0.150115967, -0.151306152, -0.151962280,
		-0.152069092, -0.151596069, -0.150497437, -0.148773193,
		-0.146362305, -0.143264771, -0.139450073, -0.134887695,
		-0.129577637, -0.123474121, -0.116577148, -0.108856201,
		0.100311279, 0.090927124, 0.080688477, 0.069595337,
		0.057617188, 0.044784546, 0.031082153, 0.016510010,
		0.001068115, -0.015228271, -0.032379150, -0.050354004,
		-0.069168091, -0.088775635, -0.109161377, -0.130310059,
		-0.152206421, -0.174789429, -0.198059082, -0.221984863,
		-0.246505737, -0.271591187, -0.297210693, -0.323318481,
		-0.349868774, -0.376800537, -0.404083252, -0.431655884,
		-0.459472656, -0.487472534, -0.515609741, -0.543823242,
		-0.572036743, -0.600219727, -0.628295898, -0.656219482,
		-0.683914185, -0.711318970, -0.738372803, -0.765029907,
		-0.791213989, -0.816864014, -0.841949463, -0.866363525,
		-0.890090942, -0.913055420, -0.935195923, -0.956481934,
		-0.976852417, -0.996246338, -1.014617920, -1.031936646,
		-1.048156738, -1.063217163, -1.077117920, -1.089782715,
		-1.101211548, -1.111373901, -1.120223999, -1.127746582,
		-1.133926392, -1.138763428, -1.142211914, -1.144287109,
		1.144989014, 1.144287109, 1.142211914, 1.138763428,
		1.133926392, 1.127746582, 1.120223999, 1.111373901,
		1.101211548, 1.089782715, 1.077117920, 1.063217163,
		1.048156738, 1.031936646, 1.014617920, 0.996246338,
		0.976852417, 0.956481934, 0.935195923, 0.913055420,
		0.890090942, 0.866363525, 0.841949463, 0.816864014,
		0.791213989, 0.765029907, 0.738372803, 0.711318970,
		0.683914185, 0.656219482, 0.628295898, 0.600219727,
		0.572036743, 0.543823242, 0.515609741, 0.487472534,
		0.459472656, 0.431655884, 0.404083252, 0.376800537,
		0.349868774, 0.323318481, 0.297210693, 0.271591187,
		0.246505737, 0.221984863, 0.198059082, 0.174789429,
		0.152206421, 0.130310059, 0.109161377, 0.088775635,
		0.069168091, 0.050354004, 0.032379150, 0.015228271,
		-0.001068115, -0.016510010, -0.031082153, -0.044784546,
		-0.057617188, -0.069595337, -0.080688477, -0.090927124,
		0.100311279, 0.108856201, 0.116577148, 0.123474121,
		0.129577637, 0.134887695, 0.139450073, 0.143264771,
		0.146362305, 0.148773193, 0.150497437, 0.151596069,
		0.152069092, 0.151962280, 0.151306152, 0.150115967,
		0.148422241, 0.146255493, 0.143676758, 0.140670776,
		0.137298584, 0.133590698, 0.129562378, 0.125259399,
		0.120697021, 0.115921021, 0.110946655, 0.105819702,
		0.100540161, 0.095169067, 0.089706421, 0.084182739,
		0.078628540, 0.073059082, 0.067520142, 0.061996460,
		0.056533813, 0.051132202, 0.045837402, 0.040634155,
		0.035552979, 0.030609131, 0.025817871, 0.021179199,
		0.016708374, 0.012420654, 0.008316040, 0.004394531,
		0.000686646, -0.002822876, -0.006134033, -0.009231567,
		-0.012115479, -0.014801025, -0.017257690, -0.019531250,
		-0.021575928, -0.023422241, -0.025085449, -0.026535034,
		-0.027801514, -0.028884888, -0.029785156, -0.030517578,
		0.031082153, 0.031478882, 0.031738281, 0.031845093,
		0.031814575, 0.031661987, 0.031387329, 0.031005859,
		0.030532837, 0.029937744, 0.029281616, 0.028533936,
		0.027725220, 0.026840210, 0.025909424, 0.024932861,
		0.023910522, 0.022857666, 0.021789551, 0.020690918,
		0.019577026, 0.018463135, 0.017349243, 0.016235352,
		0.015121460, 0.014022827, 0.012939453, 0.011886597,
		0.010848999, 0.009841919, 0.008865356, 0.007919312,
		0.007003784, 0.006118774, 0.005294800, 0.004486084,
		0.003723145, 0.003005981, 0.002334595, 0.001693726,
		0.001098633, 0.000549316, 0.000030518, -0.000442505,
		-0.000869751, -0.001266479, -0.001617432, -0.001937866,
		-0.002227783, -0.002487183, -0.002700806, -0.002883911,
		-0.003051758, -0.003173828, -0.003280640, -0.003372192,
		-0.003417969, -0.003463745, -0.003479004, -0.003479004,
		-0.003463745, -0.003433228, -0.003387451, -0.003326416,
		0.003250122, 0.003173828, 0.003082275, 0.002990723,
		0.002899170, 0.002792358, 0.002685547, 0.002578735,
		0.002456665, 0.002349854, 0.002243042, 0.002120972,
		0.002014160, 0.001907349, 0.001785278, 0.001693726,
		0.001586914, 0.001480103, 0.001388550, 0.001296997,
		0.001205444, 0.001113892, 0.001037598, 0.000961304,
		0.000885010, 0.000808716, 0.000747681, 0.000686646,
		0.000625610, 0.000579834, 0.000534058, 0.000473022,
		0.000442505, 0.000396729, 0.000366211, 0.000320435,
		0.000289917, 0.000259399, 0.000244141, 0.000213623,
		0.000198364, 0.000167847, 0.000152588, 0.000137329,
		0.000122070, 0.000106812, 0.000106812, 0.000091553,
		0.000076294, 0.000076294, 0.000061035, 0.000061035,
		0.000045776, 0.000045776, 0.000030518, 0.000030518,
		0.000030518, 0.000030518, 0.000015259, 0.000015259,
		0.000015259, 0.000015259, 0.000015259, 0.000015259
	];	
}
function frame_init_synth_nwin() {
	
	//Initialize base output array
	var _out = array_create(64);
	
	//Fill array with values
	for(var i = 0; i < 64; i++) {
		_out[i] = array_create(32);
		for(var j = 0; j < 32; j++)
			_out[i][j] = cos(((16+i) * (2*j+1)) * (pi / 64));
	}
	
	//Return
	return _out;
}