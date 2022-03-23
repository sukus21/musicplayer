//Copy executable to appdata
file_copy(working_directory + "main", working_directory + "convert");

fullpath = "/mnt/127C43E17C43BE6B/OneDrive/Musik"

files = ds_list_create();

//Read all files
for(var _file = file_find_first(fullpath + "/*.mp3", 0); _file != ""; _file = file_find_next()) {
	ds_list_add(files, _file);
}

ds_list_sort(files, true);
for(var i = 0; i < ds_list_size(files); i++) {
	show_debug_message(files[| i]);
}

draw_set_font(fnt_determination);

mouse_song = noone;

sound_playing = noone;
sound_buffer = noone;

show_debug_message(filename_path("main"));

execute_shell("touch /home/sukus/.config/MP3player/weewee", true);
execute_shell("echo balls", false)
execute_shell("/home/sukus/.config/MP3player/convert", false);