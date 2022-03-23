mouse_song = mouse_y div 32;


if(mouse_check_button_pressed(mb_left)) {
	//Try to do the thing
	var _song = fullpath + "/" + files[| mouse_song];
	execute_shell("./main", true);

	if(file_exists("error")) {
		var _buf = buffer_load("error");
		show_debug_message(buffer_read(_buf, buffer_text));
		buffer_delete("error");
	}

	else if(file_exists("smplr")) {
	
		//Get samplerate
		var _samplebuf = buffer_load("smplr");
		var _rate = buffer_read(_samplebuf, buffer_s32);
		var _length = buffer_read(_samplebuf, buffer_u64);
		buffer_delete(_samplebuf);
	
		//Open file
		sound_buffer = buffer_load("out.raw");
		sound_playing = audio_create_buffer_sound(sound_buffer, buffer_s16, _rate, 0, _length, 2);
		audio_play_sound(sound_playing, 0, false);
	}

	file_delete("smplr");
	file_delete("error");
	file_delete("out.raw");
}