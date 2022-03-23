function bits_t(p_array = noone) constructor {
	vec = p_array;
	bitpos = 0;
	bytepos = 0;
}

//Read value from bitstream
function bits_read(p_bits, p_num) {
	
	//Make sure theres things to read
	if(p_num == 0) return 0;
	if(array_length(p_bits.vec) <= p_bits.bytepos)
		return 0;
	
	//Read values
	var _bb = array_create(4);
	for(var i = 0; i < 4 and p_bits.bytepos + i < array_length(p_bits.vec); i++) {
		_bb[i] = p_bits.vec[p_bits.bytepos + i];
	}
	
	//Convert to s32
	var _val = (_bb[0] << 24) | (_bb[1] << 16) | (_bb[2] << 8) | _bb[3];
	
	//Bit stuff
	_val = (_val << p_bits.bitpos) & 0xFFFFFFFF;
	_val = _val >> (32 - p_num);
	p_bits.bytepos += (p_bits.bitpos + p_num) >> 3;
	p_bits.bitpos = (p_bits.bitpos + p_num) & 0x07;
	
	//Return read value
	//show_debug_message("n: " + string(p_num) + ", val: " + string(_val));
	return _val;
}

function bits_append(p_bits, p_buf) {
	p_bits.vec = array_append(p_bits.vec, p_buf);
	return p_bits.vec;
}

function bits_tail(p_bits, p_offset) {

	//Special case
	if(p_offset == 0)
		return array_create(0);
	
	//Um
	var _base = array_length(p_bits.vec) - p_offset;
	var _len = array_length(p_bits.vec) - _base;
	
	var _arr = array_create(_len);
	array_copy(_arr, 0, p_bits.vec, _base, _len);
	return _arr;
}

function bits_bitpos(p_bits) {
	return (p_bits.bytepos << 3) + p_bits.bitpos;
}

//Read singular bit
function bits_single(p_bits) {
	if(array_length(p_bits.vec) <= p_bits.bytepos)
		return 0;
	
	//Read values
	var _bb = array_create(4);
	for(var i = 0; i < 4 and p_bits.bytepos + i < array_length(p_bits.vec); i++) {
		_bb[i] = p_bits.vec[p_bits.bytepos + i];
	}
	
	//Convert to s32
	var _val = (_bb[0] << 24) | (_bb[1] << 16) | (_bb[2] << 8) | _bb[3];
	
	//Bit stuff
	_val = (_val << p_bits.bitpos) & 0xFFFFFFFF;
	_val = _val >> 31;
	p_bits.bytepos += (p_bits.bitpos + 1) >> 3;
	p_bits.bitpos = (p_bits.bitpos + 1) & 0x07;
	
	return _val;
}

function bits_setpos(p_bits, p_pos) {
	p_bits.bytepos = p_pos >> 3;
	p_bits.bitpos = p_pos & 0x07;
}