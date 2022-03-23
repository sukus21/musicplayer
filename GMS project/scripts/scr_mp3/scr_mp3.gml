function mp3_decode(p_buffer) {
	
	//Create decoder
	var _decoder = decoder_create(p_buffer);
	if(is_string(_decoder)) {
		show_debug_message(_decoder);
		return;
	}
	
	//Do the thing
	for(var i = 1; i < _decoder.frame_count; i++) {
		decoder_readframes(_decoder);
	}
	
	buffer_seek(_decoder.buf, buffer_seek_start, 0);
	var _s = buffer_tell(_decoder.buf);
	var _sum = 0;
	for(var i = 0; i < _s; i++)
		_sum += buffer_read(_decoder.buf, buffer_s16);
	
	show_debug_message(_sum);
	
	buffer_save(_decoder.buf, working_directory + "out.raw");
	show_debug_message("I'm trying");
	return _decoder;
}