package player

import (
	"bytes"
	"encoding/binary"
	"fmt"
	"io"
	"os"

	"github.com/hajimehoshi/go-mp3"
	"github.com/hajimehoshi/oto"
)

var plswait bool = false
var context *oto.Context = nil
var current *oto.Player = nil
var Volume float64 = 0.1
var Paused bool = false
var Looping bool = false
var stopplaying chan struct{} = nil
var SongEnded chan struct{} = make(chan struct{})

func Run(path string) error {

	if plswait {
		fmt.Println("PLEASE wait :)")
		return nil
	}
	plswait = true

	//Open file
	f, err := os.ReadFile(path)
	if err != nil {
		plswait = false
		return err
	}

	//Create decoder
	d, err := mp3.NewDecoder(bytes.NewReader(f))
	if err != nil {
		plswait = false
		return err
	}

	if stopplaying != nil {
		stopplaying <- struct{}{}
		<-stopplaying
	} else {
		stopplaying = make(chan struct{})
	}

	//Create context and player
	context, err = oto.NewContext(d.SampleRate(), 2, 2, 16384)
	if err != nil {
		plswait = false
		return err
	}
	current = context.NewPlayer()

	//Play music
	go func() {
		for {
			_, err := io.Copy(current, myReader{d})
			if err != nil {
				fmt.Println(err.Error())
				return
			}

			if plswait {

				//Song was closed by force
				fmt.Println("Song was stopped prematurely")
				current.Close()
				context.Close()
				context = nil
				stopplaying <- struct{}{}

			} else {

				//Song just ended
				if !Looping {
					current.Close()
					context.Close()
					context = nil
					stopplaying = nil
					SongEnded <- struct{}{}
					return
				} else {
					fmt.Println("Looping song")
					d.Seek(0, io.SeekStart)
				}
			}
		}
	}()

	plswait = false
	return nil
}

type myReader struct {
	d *mp3.Decoder
}

func (d myReader) Read(buf []byte) (int, error) {

	select {
	case <-stopplaying: //Stop playing song
		return 0, io.EOF
	default:
	}

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
