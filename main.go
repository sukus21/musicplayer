package main

import (
	"fmt"
	"io/fs"
	"io/ioutil"

	"fyne.io/fyne/v2"
	"fyne.io/fyne/v2/app"
	"fyne.io/fyne/v2/container"
	"fyne.io/fyne/v2/layout"
	"fyne.io/fyne/v2/theme"
	"fyne.io/fyne/v2/widget"
)

var songlist []*song = make([]*song, 0, 1024)

func main() {

	//Create app, window and layout
	app := app.New()
	window := app.NewWindow("amogus")
	content := widget.NewList(
		func() int {
			return len(songlist)
		},
		func() fyne.CanvasObject {
			return CreateSongContent()
		},
		func(i widget.ListItemID, o fyne.CanvasObject) {
			songlist[i].content = o
		},
	)
	scroll := container.NewVScroll(content)

	scroll.OnScrolled = func(p fyne.Position) {
		for _, s := range songlist {
			if s.content.Position().Y < scroll.Offset.Y || s.content.Position().Y > scroll.Offset.Y+480 {
				s.content.Hide()
				s.filler.Show()
			} else {
				s.content.Show()
				s.filler.Hide()
			}
		}
	}

	//Get all songs
	songs, err := getFiles("/mnt/127C43E17C43BE6B/OneDrive/Musik")
	if err != nil {
		panic(err.Error())
	}

	//Add songs to vbox
	for i, f := range songs {
		s := addSong(f.Name(), "")
		songlist = append(songlist, s)
		s.content.Hide()
		content.Add(s.content)
		s.number = i

		if i&7 == 0 {
			content.Add(widget.NewLabel("filler"))
		}
	}

	window.SetContent(scroll)
	content.Resize(fyne.NewSize(640, 480))
	window.Resize(fyne.NewSize(640, 480))
	window.ShowAndRun()
}

func addSong(name string, path string) *song {

	//Create song struct
	s := NewSong(name, name)
	s.CreateContent()
	return s
}

func NewSong(name string, path string) *song {
	s := song{
		name: name,
		path: path,
	}

	return &s
}

func (s *song) CreateContent() *fyne.Container {
	content := container.New(layout.NewHBoxLayout())
	s.content = content

	//Add play button
	content.Add(widget.NewButtonWithIcon("", theme.MediaPlayIcon(), func() {
		err := s.Play()
		if err != nil {
			fmt.Println(err.Error())
		}
	}))

	//Add name label
	content.Add(widget.NewLabel(s.name))

	//Create filler object
	spacer := container.New(layout.NewHBoxLayout(), layout.NewSpacer())
	spacer.Hide()
	s.filler = spacer

	//Return
	return content
}

func CreateSongContent() *fyne.Container {
	s := song{}
	return s.CreateContent()
}

func (s *song) Play() error {
	fmt.Printf("Playing song: %s", s.name)
	return nil
}

type song struct {
	name    string
	path    string
	number  int
	content *fyne.Container
	filler  *fyne.Container
}

//Get files from folder in alphabethical order
func getFiles(dir string) ([]fs.FileInfo, error) {

	//Try and get files
	files, err := ioutil.ReadDir(dir)
	if err != nil {
		return nil, err
	}

	//Sorting map
	sorting := make(map[int]string)
	getfileid := make(map[string]fs.FileInfo)
	count := 0
	for i := 0; i < len(files); i++ {
		if !files[i].IsDir() {
			sorting[count] = files[i].Name()
			getfileid[files[i].Name()] = files[i]
			count++
		}
	}

	//Do the work
	for i := 0; i < len(sorting); i++ {
		a := sorting[i]

		for j := i + 1; j < len(sorting); j++ {
			b := sorting[i]

			//Check alphabetical order
			higher := false
			for k := 0; k < min(len(a), len(b)); k++ {
				if a[k] > b[k] {
					higher = true
					break
				}
			}

			//Swap entries around maybe
			if higher {
				sorting[i] = b
				sorting[j] = a
			}
		}
	}

	//Convert to slice
	output := make([]fs.FileInfo, len(sorting))
	for i := 0; i < len(sorting); i++ {
		output[i] = getfileid[sorting[i]]
	}

	//Return
	return output, nil
}

//REALLY easy min function
func min(a int, b int) int {
	if a < b {
		return a
	}
	return b
}
