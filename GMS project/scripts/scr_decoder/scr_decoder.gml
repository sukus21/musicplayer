function decoder_t(p_buffer) constructor {
	
	source = p_buffer;
	frame = noone;
	samplerate = -1;
	buf = noone;
		
	frame_starts = ds_list_create();
	
	bytes_perframe = -1;
	length = -1;
	frame_count = -1;
}

function decoder_create(p_buffer) {

	var _decoder = new decoder_t(p_buffer);
	
	//Go to start of buffer, just in case
	buffer_seek(p_buffer, buffer_seek_start, 0);
	decoder_skiptags(_decoder);
	
	//Read a frame
	var _res = decoder_readframes(_decoder);
	if(is_string(_res))
		return _res;
	
	
	//Get sampling frequency
	_decoder.samplerate = frameheader_samplingfrequency_value(_decoder.frame.header);
	if(is_string(_decoder.samplerate))
		return _decoder.samplerate;
	
	//Ensure length or something
	var _res = decoder_ensure_validity(_decoder);
	if(is_string(_res))
		return _decoder.samplerate;
	
	//Return structure
	return _decoder;
}

function decoder_skiptags(p_decoder) {
	
	//Read first three bytes
	var _tag = chr(buffer_read(p_decoder.source, buffer_u8));
	_tag += chr(buffer_read(p_decoder.source, buffer_u8));
	_tag += chr(buffer_read(p_decoder.source, buffer_u8));
	//show_debug_message(_tag);
	
	//Switch thingy
	switch(_tag) {
		
		//Skip known length
		case "TAG": {
			
			//Skip all of this garbage
			buffer_seek(p_decoder.source, buffer_seek_relative, 125);
			return;
		}
		
		//Skip unknown length
		case "ID3": {
			
			//Skip 3 bytes ahead
			buffer_seek(p_decoder.source, buffer_seek_relative, 3);
			
			//Get Get skip size and skip
			var _size = buffer_read(p_decoder.source, buffer_u8) << 21;
			_size += buffer_read(p_decoder.source, buffer_u8) << 14;
			_size += buffer_read(p_decoder.source, buffer_u8) << 7;
			_size += buffer_read(p_decoder.source, buffer_u8);
			buffer_seek(p_decoder.source, buffer_seek_relative, _size);
			return;
		}
		
		//Uh, this is not an MP3 file
		default: {
			
			//Something went wrong
			show_debug_message("This aint right");
			return ;
		}
	}
}

//Can return errors
function decoder_readframes(p_decoder) {

	static framecount = 0;
	show_debug_message("FRAME " + string(framecount++));
	
	//Read an entire frame
	p_decoder.frame = frame_read(p_decoder.source, p_decoder.frame);
	if(is_string(p_decoder.frame))
		return p_decoder.frame;
	
	//Decode frame to raw audio
	var _dec = frame_decode(p_decoder.frame);
	p_decoder.buf = buffer_append(p_decoder.buf, _dec);
	buffer_delete(_dec);
	
	//Return
	return noone;
}

function decoder_ensure_validity(p_decoder) {
	
	if(p_decoder.length != -1)
		return;
	
	//Save source position, but reset buffer seek position(s)
	var _pos = buffer_tell(p_decoder.source);
	buffer_seek(p_decoder.source, buffer_seek_start, 0);
	
	//And then skip tags
	decoder_skiptags(p_decoder);
	
	//Get total length of finished buffer
	var _length = 0;
	while(true) {
		
		//Read frame header
		var _header = frameheader_read(p_decoder.source);
		if(is_string(_header)) {
			if(_header == "¤end")
				break;
			else
				return _header;
		}
		
		//Get unpacked length of frame
		ds_list_add(p_decoder.frame_starts, buffer_tell(p_decoder.source));
		p_decoder.bytes_perframe = frameheader_bytesperframe(_header);
		_length += p_decoder.bytes_perframe;
		
		//Skip frame body
		var _size = frameheader_framesize(_header);
		if(is_string(_size))
			return _size;
		buffer_seek(p_decoder.source, buffer_seek_relative, _size-4);
		
		//Break if end of buffer is reached
		if(buffer_tell(p_decoder.source) >= buffer_get_size(p_decoder.source))
			break;
	}
	
	//Set length property of decoder
	p_decoder.length = _length;
	p_decoder.frame_count = ds_list_size(p_decoder.frame_starts);
	ds_list_destroy(p_decoder.frame_starts);
	
	//Copy read frame to new buffer
	var _newbuf = buffer_create(_length, buffer_fixed, 1);
	buffer_append(_newbuf, p_decoder.buf);
	buffer_delete(p_decoder.buf);
	p_decoder.buf = _newbuf;
	
	//Restore source read position and return
	buffer_seek(p_decoder.source, buffer_seek_start, _pos);
	return;
}

//Can return errors
function decoder_read(p_decoder) {
	
	//Keep trying to read until it hits something
	var _pos = buffer_tell(p_decoder.buf);
	while(buffer_tell(p_decoder.buf) == _pos) {
		
		//Read frame
		var _err = decoder_readframes(p_decoder);
		if(is_string(_err))
			return _err;
	}
}