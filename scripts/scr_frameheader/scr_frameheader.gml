//Get emphasis (bits 0-1)
function frameheader_emphasis(p_header) {
	return p_header & 0x00000003;	
}

//Get channel mode extension (bits 4-5)
function frameheader_channelmode_extension(p_header) {
	return (p_header & 0x00000030) >> 4;
}

//Get channel mode (bits 6-7)
function frameheader_channelmode(p_header) {
	return (p_header & 0x000000C0) >> 6;	
}

//Get the padding bit (bit 9)
function frameheader_paddingbit(p_header) {
	return (p_header & 0x00000200) >> 9;	
}

//Get sampling frequency (bits 10-11)
function frameheader_samplingfrequency(p_header) {
	return (p_header & 0x00000C00) >> 10;	
}

//Get bitrate index (bits 12-15)
function frameheader_bitrateindex(p_header) {
	return (p_header & 0x0000F000) >> 12;
}

//Get protection bit (bit 16)
function frameheader_protectionbit(p_header) {
	return (p_header & 0x00010000) >> 16;	
}

//Get mpeg layer (bits 17-18)
function frameheader_mpeglayer(p_header) {
	return (p_header & 0x00060000) >> 17;
}

//Get ID of frameheader (bits 19-20)
function frameheader_id(p_header) {
	return (p_header & 0x00180000) >> 19;
}



//Check if frame header is valid or not
function frameheader_isvalid(p_header) {
	static sync = 0xFFE00000;
	
	//Is this thing out of sync?
	if(p_header & sync) != sync
		return false;
	
	//Invalid version number?
	if(frameheader_id(p_header) == VERSION.RESERVED)
		return false;
		
	//Invalid bitrate?
	if(frameheader_bitrateindex(p_header) == 15)
		return false;
	
	//Invalid sampling frequency?
	if(frameheader_samplingfrequency(p_header) == SAMPLINGFREQUENCY_RESERVED)
		return false;
		
	//Invalid layer?
	if(frameheader_mpeglayer(p_header) == MPEGLAYER.RESERVED)
		return false;
	
	//Emphasis??
	if(frameheader_emphasis(p_header) == 2)
		return false;
	
	//Everything worked out :D
	return true;
}


//Get a frame header
function frameheader_read(p_buffer) {
	
	//Read 4 bytes
	var _buf = array_create(4);
	for(var i = 0; i < 4; i++)
		_buf[i] = buffer_read(p_buffer, buffer_u8);
	
	//Convert to a u32 and check validity
	var _header = (_buf[0] << 24) | (_buf[1] << 16) | (_buf[2] << 8) | _buf[3];
	while(!frameheader_isvalid(_header)) {
		
		//Check buffer bounds
		if(buffer_tell(p_buffer) >= buffer_get_size(p_buffer))
			return "¤end";
		
		_buf[0] = _buf[1];
		_buf[1] = _buf[2];
		_buf[2] = _buf[3];
		_buf[3] = buffer_read(p_buffer, buffer_u8);
		
		_header = (_buf[0] << 24) | (_buf[1] << 16) | (_buf[2] << 8) | _buf[3];
	}
	
	//Um
	if(frameheader_bitrateindex(_header) == 0) {
		return "mp3: free bitrate format is not supported. Header word is " + string(_header) + " at position " + string(buffer_tell(p_buffer)-4);
	}
	
	return _header;
}



//Get channel count
function frameheader_channelcount(p_header) {
	if(frameheader_channelmode(p_header) == CHANNELMODE.SINGLECHANNEL)
		return 1;
	return 2;
}

//Get actual sampling frequency
//Can return errors
function frameheader_samplingfrequency_value(p_header) {
	var _freq = -1;
	switch(frameheader_samplingfrequency(p_header)) {
		case 0: _freq = 44100; break;
		case 1: _freq = 48000; break;
		case 2: _freq = 32000; break;
		default: return "mp3: frame header has invalid sample frequency";
	}
	
	return _freq >> frameheader_samplingfrequency_low(p_header);
}

function frameheader_samplingfrequency_low(p_header) {
	if(frameheader_id(p_header) == VERSION.V1)
		return 0;
	return 1;
}

function frameheader_framesize(p_header) {
	
	//Get sampling frequency
	var _freq = frameheader_samplingfrequency_value(p_header);
	if(is_string(_freq))
		return _freq;
	
	//Calculate size and return
	var _size = (144 * frameheader_bitrate(p_header));
	_size /= _freq + frameheader_paddingbit(p_header);
	return _size >> frameheader_samplingfrequency_low(p_header);
}

function frameheader_sidesize(p_header) {
	
	//Get channel mode
	var _mono = frameheader_channelmode(p_header) == CHANNELMODE.SINGLECHANNEL;
	var _size;
	
	//Get sideinfo size
	if(frameheader_samplingfrequency_low(p_header) == 1) {
		if(_mono) _size = 9;
		else _size = 17;
	}
	else {
		if(_mono) _size = 17;
		else _size = 32;
	}
	
	//Return it
	return _size;
}

function frameheader_bitrate(p_header) {
	
	//Table of all bitrate values
	static bitrates = [
		[
			//MPEG 1 Layer 3
			[0, 32000, 40000, 48000, 56000, 64000, 80000, 96000, 112000, 128000, 160000, 192000, 224000, 256000, 320000],

			//MPEG 1 Layer 2
			[0, 32000, 48000, 56000, 64000, 80000, 96000, 112000, 128000, 160000, 192000, 224000, 256000, 320000, 384000],

			//MPEG 1 Layer 1
			[0, 32000, 64000, 96000, 128000, 160000, 192000, 224000, 256000, 288000, 320000, 352000, 384000, 416000, 448000],
		],
		[
			//MPEG2 2 Layer 3
			[0, 8000, 16000, 24000, 32000, 40000, 48000, 56000, 64000, 80000, 96000, 112000, 128000, 144000, 160000],

			//MPEG 2 Layer 2
			[0, 8000, 16000, 24000, 32000, 40000, 48000, 56000, 64000, 80000, 96000, 112000, 128000, 144000, 160000],

			//MPEG 2 Layer 1
			[0, 32000, 48000, 56000, 64000, 80000, 96000, 112000, 128000, 144000, 160000, 176000, 192000, 224000, 256000],
		]
	];
	
	//Return bitrate
	return bitrates[frameheader_samplingfrequency_low(p_header)][frameheader_mpeglayer(p_header)-1][frameheader_bitrateindex(p_header)];
}
	
function frameheader_granules(p_header) {
	return GRANULES_MPEG1 >> frameheader_samplingfrequency_low(p_header);
}

function frameheader_bytesperframe(p_header) {
	return SAMPLES_PER_GRANULE * frameheader_granules(p_header) * 4;
}

function frameheader_use_msstereo(p_header) {
	if(frameheader_channelmode(p_header) != CHANNELMODE.JOINTSTEREO)
		return false;
	
	return frameheader_channelmode_extension(p_header) & 2 != 0;
}

function frameheader_use_intensitystereo(p_header) {
	if(frameheader_channelmode(p_header) != CHANNELMODE.JOINTSTEREO)
		return false;
	
	return frameheader_channelmode_extension(p_header) & 1 != 0;
}