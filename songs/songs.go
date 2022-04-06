package songs

import (
	"fmt"
	"io/fs"
	"io/ioutil"
	"math/rand"
	"musicplayer/player"
	"strings"

	"fyne.io/fyne/v2"
	"fyne.io/fyne/v2/container"
	"fyne.io/fyne/v2/layout"
	"fyne.io/fyne/v2/theme"
	"fyne.io/fyne/v2/widget"
)

var ButtonPlayPause *widget.Button

var Allsongs []*song = make([]*song, 0, 1024)
var Songlist []*song = nil
var Playlist []*song = nil
var CurrentSong int = -1
var SongContainer *widget.List
var shuffle bool = false

type song struct {
	name       string
	path       string
	nameSearch string
	content    *fyne.Container
	number     int
}

func init() {
	go func() {
		for {
			<-player.SongEnded
			NextSong()
		}
	}()
}

func NewSong(name string, path string) *song {
	s := song{
		name:       name,
		path:       path,
		nameSearch: strings.ToLower(name),
	}

	return &s
}

func (s *song) SetContent(content *fyne.Container) {

	//Set play button function
	content.Objects[0].(*widget.Button).OnTapped = func() {
		err := s.Play()
		if err != nil {
			fmt.Println(err.Error())
		}
	}

	//Set label name
	content.Objects[1].(*widget.Label).Text = s.name
	content.Refresh()

	//Return
	s.content = content
}

func (s *song) Play() error {

	go player.Run(s.path)
	CurrentSong = s.number

	//Song is playing'
	fmt.Printf("Playing song: %s\n", s.name)
	return nil
}

//Get files from folder in alphabethical order
func GetFiles(dir string) ([]fs.FileInfo, error) {

	//Try and get files
	files, err := ioutil.ReadDir(dir)
	if err != nil {
		return nil, err
	}

	out := make([]fs.FileInfo, 0, len(files))
	for _, f := range files {
		if !f.IsDir() {
			out = append(out, f)
		}
	}

	//Return
	return out, nil
}

func GetFilesSearch(s string) []*song {
	out := make([]*song, 0, len(Allsongs))

	for _, f := range Allsongs {
		if strings.Contains(f.nameSearch, s) {
			out = append(out, f)
		}
	}

	return out
}

func NextSong() {
	CurrentSong++
	if CurrentSong < 0 || CurrentSong >= len(Playlist) {
		CurrentSong = 0
	}

	s := Playlist[CurrentSong]
	s.Play()
}

func PreviousSong() {
	CurrentSong--
	if CurrentSong < 0 {
		CurrentSong = len(Playlist) - 1
	}

	s := Playlist[CurrentSong]
	s.Play()
}

func InitializeList() {
	SongContainer = widget.NewList(

		//Get length of current song list
		func() int {
			return len(Songlist)
		},

		//Function for creating a new song element
		func() fyne.CanvasObject {
			content := container.New(layout.NewHBoxLayout())
			content.Add(widget.NewButtonWithIcon("", theme.MediaPlayIcon(), nil))
			content.Add(widget.NewLabel(""))
			return content
		},

		//Function for updating song element
		func(i widget.ListItemID, o fyne.CanvasObject) {
			Songlist[i].SetContent(o.(*fyne.Container))
		},
	)
}

func PlayPauseSong() {
	if player.Paused {
		ButtonPlayPause.Icon = theme.MediaPauseIcon()
	} else {
		ButtonPlayPause.Icon = theme.MediaPlayIcon()
	}
	ButtonPlayPause.Refresh()
	player.Paused = !player.Paused
}

func Shuffle() {
	shuffle = !shuffle
	fmt.Println("Shuffle", shuffle)
	UpdateSongOrder()
}

func UpdateSongOrder() {

	Playlist = make([]*song, len(Songlist))
	copy(Playlist, Songlist)

	//The
	if shuffle {
		for i, s := range Playlist {
			j := rand.Int() % len(Playlist)
			Playlist[i] = Playlist[j]
			Playlist[j] = s
		}
	}

	//Update song number
	for i, s := range Playlist {
		s.number = i
	}
}
