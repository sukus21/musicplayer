function mp3_decode(p_buffer) {
	
	//Create decoder
	var _decoder = decoder_create(p_buffer);
	if(is_string(_decoder)) {
		show_debug_message(_decoder);
		return;
	}
	
	//Do the thing
	repeat(_decoder.frame_count) {
		decoder_readframes(_decoder);
	}
	
	show_debug_message("I'm trying");
	return _decoder;
}