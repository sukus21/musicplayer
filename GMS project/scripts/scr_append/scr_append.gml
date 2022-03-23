function array_append(p_arr1, p_arr2) {
	var _arr = array_create(array_length(p_arr1) + array_length(p_arr2));
	array_copy(_arr,0, p_arr1, 0, array_length(p_arr1));
	array_copy(_arr, array_length(p_arr1), p_arr2, 0, array_length(p_arr2));
	return _arr;
}

//WARNING: might not work if p_dest isn't of type buffer_grow!!!
function buffer_append(p_dest, p_source) {
	
	//In case destination buffer doesn't exist, create it
	if(p_dest == noone) {
		p_dest = buffer_create(buffer_tell(p_source), buffer_grow, 2);
	}
	
	//Copy contents of source into destination
	buffer_copy(p_source, 0, buffer_tell(p_source), p_dest, buffer_tell(p_dest));
	buffer_seek(p_dest, buffer_seek_relative, buffer_tell(p_source));
	return p_dest;
}