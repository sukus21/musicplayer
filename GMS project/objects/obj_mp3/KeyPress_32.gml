//Open an MP3 file
var _fname = "test.mp3";
var _buffer = buffer_load(_fname);
var _out = mp3_decode(_buffer);

//Create sound maybe
var _snd = audio_create_buffer_sound(_out.buf, buffer_s16, _out.samplerate, 0, buffer_get_size(_out.buf), audio_stereo);
audio_play_sound(_snd, 0, false);