package player

import (
	"bytes"
	"encoding/binary"
	"io"
	"os"

	"github.com/hajimehoshi/go-mp3"
	"github.com/hajimehoshi/oto"
)

var context *oto.Context = nil
var current *oto.Player = nil
var Volume float64 = 0.1
var Paused bool = false

func Run(path string) error {

	//Open file
	f, err := os.ReadFile(path)
	if err != nil {
		return err
	}

	//Create decoder
	d, err := mp3.NewDecoder(bytes.NewReader(f))
	if err != nil {
		return err
	}

	//Close existing context
	if context != nil {
		context.Close()
		context = nil
	}

	//Create context and player
	context, err = oto.NewContext(d.SampleRate(), 2, 2, 16384)
	if err != nil {
		return err
	}
	current = context.NewPlayer()

	//Play music
	go func() {
		io.Copy(current, myReader{d})
	}()

	return nil
}

type myReader struct {
	d *mp3.Decoder
}

func (d myReader) Read(buf []byte) (int, error) {

	if Paused {
		for i := range buf {
			buf[i] = 0
		}
		return len(buf), nil
	}

	//Read
	n, err := (*mp3.Decoder)(d.d).Read(buf)
	if err != nil {
		return n, err
	}

	//Multiply by values
	for i := 0; i < n; i += 2 {

		//Multiply volume
		w := buf[i : i+2]
		sample := int16(binary.LittleEndian.Uint16(w))
		fsample := float64(sample) * Volume

		//Convert back into bytes
		sample = int16(fsample)
		binary.LittleEndian.PutUint16(w, uint16(sample))
	}

	return n, nil
}
