function array_append(p_arr1, p_arr2) {
	var _arr = array_create(array_length(p_arr1) + array_length(p_arr2));
	array_copy(_arr,0, p_arr1, 0, array_length(p_arr1));
	array_copy(_arr, array_length(p_arr1), p_arr2, 0, array_length(p_arr2));
	return _arr;
}

//WARNING: might not work if p_dest isn't of type buffer_grow!!!
function buffer_append(p_dest, p_source) {
	
	var _dest_offset = buffer_tell(p_dest);
	var _source_offset = buffer_tell(p_source);
	
	buffer_copy(p_source, _source_offset, buffer_get_size(p_source) - _source_offset, p_dest, _dest_offset);
	return p_dest;
}