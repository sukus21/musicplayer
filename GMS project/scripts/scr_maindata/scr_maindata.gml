function maindata_t() constructor {
	scalefac_l = [array_create(2), array_create(2)];
	scalefac_s = [array_create(2), array_create(2)];
	is = [array_create(2), array_create(2)];
	
	for(var i = 0; i < 2; i++) {
		for(var j = 0; j < 2; j++) {
			scalefac_l[i][j] = array_create(22);
			scalefac_s[i][j] = array_create(13);
			is[i][j] = array_create(576);
			
			for(var k = 0; k < 13; k++) {
				scalefac_s[i][j][k] = array_create(2);
			}
		}
	}
}

function maindata_read(p_buffer, p_previous, p_header, p_sideinfo) {
	
	//Calculate header audio data size
	var _channels = frameheader_channelcount(p_header);
	var _framesize = frameheader_framesize(p_header);
	if(is_string(_framesize)) return _framesize;
	if(_framesize > 2000) return "mp3: framesize = " + string(_framesize);
	var _sidesize = frameheader_sidesize(p_header);
	
	
	//Get main data size
	var _mainsize = _framesize - _sidesize - 4;
	if(frameheader_protectionbit(p_header) == 0)
		_mainsize -= 2;
	
	//Read that stuff
	var _maindata = maindata_read_sub(p_buffer, p_previous, _mainsize, p_sideinfo.maindata_begin);
	if(is_string(_maindata)) 
		return _maindata;
	
	if(frameheader_samplingfrequency_low(p_header) == 1)
		return maindata_scalefactors_mpeg2(_maindata, p_header, p_sideinfo);
		
	return maindata_scalefactors_mpeg1(_channels, _maindata, p_header, p_sideinfo);
}

function maindata_read_sub(p_buffer, p_previous, p_size, p_offset) {
	if(p_size > 1500) 
		return "mp3: size = " + string(p_size);
	
	//Is there data available from previous frames?
	if(p_previous != noone and p_offset > array_length(p_previous.vec)) {
			
		//uh
		var _buf = array_create(p_size);
		for(var i = 0; i < p_size; i++)
			_buf[i] = buffer_read(p_buffer, buffer_u8);
		
		return bits_append(p_previous, _buf);
	}
	
	//Copy data from previous frame
	var _vec = array_create(0);
	if(p_previous != noone) 
		_vec = bits_tail(p_previous, p_offset);
	
	var _buf = array_create(p_size);
	for(var i = 0; i < p_size; i++) {
		_buf[i] = buffer_read(p_buffer, buffer_u8);
	}
	
	return new bits_t(array_append(_vec, _buf));
}

function maindata_scalefactors_mpeg1(p_channels, p_maindata, p_header, p_sideinfo) {
	
	static scalefacsizes_mpeg1 = [
		[0, 0], [0, 1], [0, 2], [0, 3], [3, 0], [1, 1], [1, 2], [1, 3],
		[2, 1], [2, 2], [2, 3], [3, 1], [3, 2], [3, 3], [4, 2], [4, 3]
	];
	
	var _md = new maindata_t();
	
	for(var gr = 0; gr < 2; gr++) {
		for(var ch = 0; ch < p_channels; ch++) {
			var _part2 = bits_bitpos(p_maindata);
			
			//Get number of bits to read
			var _len1 = scalefacsizes_mpeg1[p_sideinfo.scalefac_compress[gr][ch]][0];
			var _len2 = scalefacsizes_mpeg1[p_sideinfo.scalefac_compress[gr][ch]][1];
			
			if(p_sideinfo.win_switch_flag[gr][ch] == 1 and p_sideinfo.block_type[gr][ch] == 2) {
				
				//Mixed blocks
				if(p_sideinfo.mixed_block_flag[gr][ch] != 0) {
					
					//Write scalefacl
					for(var sfb = 0; sfb < 8; sfb++)
						_md.scalefac_l[gr][ch][sfb] = bits_read(p_maindata, _len1);
					
					//Write scalefacs
					for(var sfb = 3; sfb < 12; sfb++) {
						var _rlen = sfb < 6 ? _len1 : _len2;
						for(var win = 0; win < 3; win++)
							_md.scalefac_s[gr][ch][sfb][win] = bits_read(p_maindata, _rlen);
					}
				}
				
				//Not mixed blocks
				else {
					
					//Write scalefacs
					for(var sfb = 0; sfb < 12; sfb++) {
						var _rlen = sfb < 6 ? _len1 : _len2;
						for(var win = 0; win < 3; win++)
							_md.scalefac_s[gr][ch][sfb][win] = bits_read(p_maindata, _rlen);
					}
				}
			}
			
			else {
			
				//SFB 0-5
				if(p_sideinfo.scfsi[ch][0] == 0 or gr == 0) {
					for(var sfb = 0; sfb < 6; sfb++)
						_md.scalefac_l[gr][ch][sfb] = bits_read(p_maindata, _len1);
				}
				else if(p_sideinfo.scfsi[ch][0] == 1 and gr == 1) {
					for(var sfb = 0; sfb < 6; sfb++)
						_md.scalefac_l[1][ch][sfb] = _md.scalefac_l[0][ch][sfb];
				}
				
				//SFB 6-10
				if(p_sideinfo.scfsi[ch][1] == 0 or gr == 0) {
					for(var sfb = 6; sfb < 11; sfb++)
						_md.scalefac_l[gr][ch][sfb] = bits_read(p_maindata, _len1);
				}
				else if(p_sideinfo.scfsi[ch][1] == 1 and gr == 1) {
					for(var sfb = 6; sfb < 11; sfb++)
						_md.scalefac_l[1][ch][sfb] = _md.scalefac_l[0][ch][sfb];
				}
				
				//SFB 11-15
				if(p_sideinfo.scfsi[ch][2] == 0 or gr == 0) {
					for(var sfb = 11; sfb < 16; sfb++)
						_md.scalefac_l[gr][ch][sfb] = bits_read(p_maindata, _len2);
				} 
				else if(p_sideinfo.scfsi[ch][2] == 1 and gr == 1) {
					for(var sfb = 11; sfb < 16; sfb++)
						_md.scalefac_l[1][ch][sfb] = _md.scalefac_l[0][ch][sfb];
				}
				
				// Scale factor bands 16-20
				if(p_sideinfo.scfsi[ch][3] == 0 || gr == 0) {
					for(var sfb = 16; sfb < 21; sfb++)
						_md.scalefac_l[gr][ch][sfb] = bits_read(p_maindata, _len2);
				} 
				else if(p_sideinfo.scfsi[ch][3] == 1 && gr == 1) {
					for(var sfb = 16; sfb < 21; sfb++)
						_md.scalefac_l[1][ch][sfb] = _md.scalefac_l[0][ch][sfb];
				}
			}
			
			//Huffman encoded bits
			var _err = huffman_read(p_maindata, p_header, p_sideinfo, _md, _part2, gr, ch);
			if(is_string(_err))
				return _err;
		}
	}
	
	
	//maindata_print(_md);
	
	//Return all this stuff
	return [_md, p_maindata];
}
	
function maindata_scalefactors_mpeg2(p_maindata, p_header, p_sideinfo) {
	return noone;
}

function maindata_print(p_maindata) {
	var _res = "[ ";
	for(var i = 0; i < 2; i++) {
		for(var j = 0; j < 2; j++) {
			var _sum = 0;
			for(var k = 0; k < array_length(p_maindata.is[i][j]); k++)
				_sum += p_maindata.is[i][j][k];
			
			_res += string(_sum) + " ";
		}
	}
	
	_res += "]";
	//show_debug_message(_res);
}