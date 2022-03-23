for(var i = 0; i < ds_list_size(files); i++) {
	draw_text(0, i * 32, files[| i]);
}

if(mouse_song != noone)
	draw_text_color(0, mouse_song*32, files[| mouse_song], c_gray, c_gray, c_gray, c_gray, 1);