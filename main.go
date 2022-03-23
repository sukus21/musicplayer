package main

import (
	"encoding/binary"
	"io"
	"os"

	"github.com/hajimehoshi/go-mp3"
)

func convert(fname string) error {
	f, err := os.Open(fname)
	if err != nil {
		return err
	}
	defer f.Close()

	d, err := mp3.NewDecoder(f)
	if err != nil {
		return err
	}

	//Open output file
	o, err := os.Create("out.raw")
	if err != nil {
		return err
	}

	//Write main file
	if _, err := io.Copy(o, d); err != nil {
		return err
	}
	o.Close()

	//Write file with samplerate
	o, err = os.Create("smplr")
	if err != nil {
		return err
	}

	//Write thing
	binary.Write(o, binary.LittleEndian, d.SampleRate())
	binary.Write(o, binary.LittleEndian, d.Length())
	o.Close()

	//Return nil, because no errors happened :)
	return nil
}

func main() {

	//fmt.Println("ahh scary!")

	//Get file name
	//if len(os.Args) != 2 {
	//	close(errors.New(fmt.Sprintf("Expected 2 arguments, got %d.", len(os.Args))))
	//}

	err := convert("test.mp3")
	if err != nil {
		close(err)
	}
}

func close(err error) {
	f, _ := os.Create("error")
	f.WriteString(err.Error())
	f.Close()
	os.Exit(1)
}
