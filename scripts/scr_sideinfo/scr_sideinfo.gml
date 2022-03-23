function sideinfo_bits_to_read(i, j = undefined) {
	static table = [
		[9, 5, 3, 4],
		[8, 1, 2, 9]
	];
	
	if(j == undefined) return table[i];
	else return table[i][j];
}

function sideinfo_t() constructor {
	maindata_begin = 0;
	private_bits = 0;
	
	scfsi = [[0,0,0,0], [0,0,0,0]];
	part2_3length = [[0, 0], [0, 0]];
	big_values = [[0, 0], [0, 0]];
	global_gain = [[0, 0], [0, 0]];
	scalefac_compress = [[0, 0], [0, 0]];
	win_switch_flag = [[0, 0], [0, 0]];
	
	block_type = [[0, 0], [0, 0]];
	mixed_block_flag = [[0, 0], [0, 0]];
	table_select = [
		[[0, 0, 0], [0, 0, 0]],
		[[0, 0, 0], [0, 0, 0]],
	];
	subblock_gain = [
		[[0, 0, 0], [0, 0, 0]],
		[[0, 0, 0], [0, 0, 0]],
	];
	
	region0_count = [[0, 0], [0, 0]];
	region1_count = [[0, 0], [0, 0]];
	
	preflag = [[0, 0], [0, 0]];
	scalefac_scale = [[0, 0], [0, 0]];
	count1_table_select = [[0, 0], [0, 0]];
	count1 = [[0, 0], [0, 0]];
}

function sideinfo_read(p_buffer, p_header) {
	
	var _channels = frameheader_channelcount(p_header);
	var _framesize = frameheader_framesize(p_header);
	if(is_string(_framesize))
		return _framesize;
	
	//Is frame too big?
	if(_framesize > 2000)
		return "mp3: framesize = " + string(_framesize);
	
	//Get main size
	var _sidesize = frameheader_sidesize(p_header);
	var _mainsize = _framesize - _sidesize - 4;
	if(frameheader_protectionbit(p_header) == 0)
		_mainsize -= 2;
	
	//Read bytes
	var _buf = array_create(_sidesize);
	for(var i = 0; i < _sidesize; i++) {
		_buf[i] = buffer_read(p_buffer, buffer_u8);	
	}
	
	//What
	var _bits = new bits_t(_buf);
	var _mpeg1frame = frameheader_samplingfrequency_low(p_header) == 0;
	var _bits_to_read = sideinfo_bits_to_read(frameheader_samplingfrequency_low(p_header));
	
	//Parse audio data
	var _sideinfo = new sideinfo_t();
	_sideinfo.maindata_begin = bits_read(_bits, _bits_to_read[0]);
	
	//Get private bits, useless
	if(frameheader_channelmode(p_header) == CHANNELMODE.SINGLECHANNEL)
		_sideinfo.private_bits = bits_read(_bits, _bits_to_read[1]);
	else 
		_sideinfo.private_bits = bits_read(_bits, _bits_to_read[2]);
	
	//Is this an MPEG1 frame?
	if(_mpeg1frame) {
		
		//Get scale factor select information
		for(var _ch = 0; _ch < _channels; _ch++) {
			for(var _band = 0; _band < 4; _band++) {
				_sideinfo.scfsi[_ch][_band] = bits_read(_bits, 1);	
			}
		}
	}
	
	//Get the rest of the side information
	for(var _gr = 0; _gr < frameheader_granules(p_header); _gr++) {
		
		//Repeat for each channel
		for(var _ch = 0; _ch < _channels; _ch++) {
			
			_sideinfo.part2_3length[_gr][_ch] = bits_read(_bits, 12);
			_sideinfo.big_values[_gr][_ch] = bits_read(_bits, 9);
			_sideinfo.global_gain[_gr][_ch] = bits_read(_bits, 8);
			
			_sideinfo.scalefac_compress[_gr][_ch] = bits_read(_bits, _bits_to_read[3]);
			_sideinfo.win_switch_flag[_gr][_ch] = bits_read(_bits, 1);
			
			//I don't even
			if(_sideinfo.win_switch_flag[_gr][_ch] == 1) {
				_sideinfo.block_type[_gr][_ch] = bits_read(_bits, 2);
				_sideinfo.mixed_block_flag[_gr][_ch] = bits_read(_bits, 1);
				
				for(var r = 0; r < 2; r++)
					_sideinfo.table_select[_gr][_ch][r] = bits_read(_bits, 5);
				
				for(var w = 0; w < 3; w++)
					_sideinfo.subblock_gain[_gr][_ch][w] = bits_read(_bits, 3);
				
				//Region count things??
				if(_sideinfo.block_type[_gr][_ch] == 2 and _sideinfo.mixed_block_flag[_gr][_ch] == 0)
					_sideinfo.region0_count[_gr][_ch] = 8;
				else
					_sideinfo.region0_count[_gr][_ch] = 7;
				_sideinfo.region1_count[_gr][_ch] = 20 - _sideinfo.region0_count[_gr][_ch];
			}
			
			//I am lost
			else {
				for(var r = 0; r < 3; r++)
					_sideinfo.table_select[_gr][_ch][r] = bits_read(_bits, 5);
				
				_sideinfo.region0_count[_gr][_ch] = bits_read(_bits, 4);
				_sideinfo.region1_count[_gr][_ch] = bits_read(_bits, 3);
				_sideinfo.block_type[_gr][_ch] = 0;
				
				if(!_mpeg1frame) _sideinfo.mixed_block_flag[0][_ch] = 0;
			}
			
			if(_mpeg1frame) _sideinfo.preflag[_gr][_ch] = bits_read(_bits, 1);
			_sideinfo.scalefac_scale[_gr][_ch] = bits_read(_bits, 1);
			_sideinfo.count1_table_select[_gr][_ch] = bits_read(_bits, 1);
		}
	}
	
	//Finally, return
	return _sideinfo;
}