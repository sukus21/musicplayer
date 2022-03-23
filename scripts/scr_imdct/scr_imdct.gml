function imdct_init_windata() {
	
	//Initialize variables
	var i, _out = [array_create(36), array_create(36), array_create(36), array_create(36)];
	
	//0
	for(i = 0; i < 36; i++)
		_out[0][i] = sin(pi / 36 * (i + 0.5));
	
	//1
	for(i = 0; i < 18; i++)
		_out[1][i] = sin(pi / 36 * (i + 0.5));
	for(; i < 24; i++)
		_out[1][i] = 1;
	for(; i < 30; i++)
		_out[1][i] = sin(pi / 12 * (i + 0.5 - 18));
	for(; i < 36; i++)
		_out[1][i] = 0;
	
	//2
	for(i = 0; i < 12; i++)
		_out[2][i] = sin(pi / 36 * (i + 0.5));
	for(; i < 36; i++)
		_out[2][i] = 0;
	
	//3
	for(i = 0; i < 6; i++)
		_out[3][i] = 0;
	for(; i < 12; i++)
		_out[3][i] = sin(pi / 12 * (i - 5.5));
	for(; i < 18; i++)
		_out[3][i] = 1;
	for(; i < 36; i++)
		_out[3][i] = sin(pi / 12 * (i + 0.5));
	
	//Return
	return _out;
}
function imdct_init_cos12() {
	
	//Initialize output array
	var _out = array_create(6);
	
	for(var i = 0; i < 6; i++)
		_out[i] = array_create(12);
		for(var j = 0; j < 12; j++)
			_out[i][j] = cos(pi / 24 * (2 * j + 7) * (2 * i + 1));
	
	//Return
	return _out;
}
function imdct_init_cos36() {
	
	//Initialize output array
	var _out = array_create(18);
	
	for(var i = 0; i < 18; i++)
		_out[i] = array_create(36);
		for(var j = 0; j < 36; j++)
			_out[i][j] = cos(pi / 72 * (2 * j + 19) * (2 * i + 1));
	
	//Return
	return _out;	
}

function imdct_win(p_input, p_blocktype) {
	
	static windata = imdct_init_windata();
	static cos12 = imdct_init_cos12();
	static cos36 = imdct_init_cos36();
	
	var _out = array_create(36);
	if(p_blocktype == 2) {
		
		//Do thing
		for(var i = 0; i < 3; i++) {
			for(var j = 0; j < 12; j++) {
				var _sum = 0;
				for(var k = 0; k < 6; k++)
					_sum += p_input[i+3*k] * cos12[k][j];
			}
			
			_out[6*i + j+6] += _sum * windata[p_blocktype][j];
		}
		
		//Return
		return _out;
	}
	
	for(var i = 0; i < 36; i++) {
		var _sum = 0;
		for(var j = 0; j < 18; j++)
			_sum += p_input[j] * cos36[j][i];
			
		_out[i] = _sum * windata[p_blocktype][i];
	}
	
	//Return
	return _out;
}
