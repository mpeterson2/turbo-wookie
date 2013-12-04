library LibraryList;
import "dart:html";
import "package:polymer/polymer.dart";
import "package:json_object/json_object.dart";
import "song.dart";

/**
 * Displays every song in the library.
 */
@CustomTag('library-list')
class LibraryList extends PolymerElement {

  List<Song> songs;
  TableElement table;
  TableElement tableBody;
  InputElement search;
  bool titleSort;
  bool artistSort;
  bool albumSort;

  LibraryList.created()
      : super.created() {
    titleSort = false;
    artistSort = false;
    albumSort = false;
  }

  void enteredView() {
    print("hello1");
    songs = new List<Song>();
    print("hello2");
    table = $["songs"];
    print("hello3");
    tableBody = $["songsBody"];
    print("hello4");
    search = $["search"];
    print("hello?");
    getAllSongs();
    print("you suck");
    setupEvents();
  }

  void setupEvents() {
    TableSectionElement head = table.tHead;
    TableRowElement row = head.children[0];
    row.children.forEach((TableCellElement cell) {
      if(cell.innerHtml != "Add") {
        cell.onClick.listen((MouseEvent e) {
          sort(cell.innerHtml);
        });
      }
    });

    search.onInput.listen((Event e) {
      filter(search.value);
    });
  }

  /**
   * Get all the songs in the library and add them to the page.
   */
  void getAllSongs() {
    HttpRequest.request("/songs")
    .then((HttpRequest request) {
      tableBody.children.clear();
      JsonObject songsJson = new JsonObject.fromJsonString(request.responseText);
      print("hello?");
      print(request.responseText);
      songsJson.forEach((JsonObject songJson) {
        Song song = new Song.fromJson(songJson);
        songs.add(song);

        TableRowElement row = tableBody.addRow();
        createSongRow(row, song);
      });
    });
  }

  /**
   * Helper method for creating a row in the song table.
   */
  void createSongRow(TableRowElement row, Song song) {

    TableCellElement title = new TableCellElement();
    title.text = song.title;
    TableCellElement artist = new TableCellElement();
    artist.text = song.artist;
    TableCellElement album = new TableCellElement();
    album.text = song.album;

    ButtonElement button = new ButtonElement();
    button.innerHtml = "<img src='../img/add.svg'>";
    button.onClick.listen((MouseEvent e) {
      song.addToPlaylist();
    });
    button.onFocus.listen((e) {
      button.blur();
    });

    row.children.add(title);
    row.children.add(artist);
    row.children.add(album);
    row.children.add(button);
  }

  void filter(String filter) {
    List<TableRowElement> rows = tableBody.children;
    for(TableRowElement row in rows) {
      List<Element> children = row.children;
      for(Element child in children) {
        if(child.innerHtml.toLowerCase().contains(filter.toLowerCase())) {
          row.hidden = false;
          break;
        }
        else {
          row.hidden = true;
        }
      }
    }
  }

  void sort(String sortBy) {
    if(sortBy == "Title") {
      songs.sort((a, b) => a.title.compareTo(b.title));
      if(titleSort) {
        songs = songs.reversed.toList();
        titleSort = true;
      }
      titleSort = !titleSort;
      artistSort = false;
      albumSort = false;
    }
    else if(sortBy == "Artist") {
      songs.sort((a, b) => a.artist.compareTo(b.artist));
      if(artistSort) {
        songs = songs.reversed.toList();
        artistSort = true;
      }
      artistSort = !artistSort;
      titleSort = false;
      albumSort = false;
    }
    else if(sortBy == "Album") {
      songs.sort((a, b) => a.album.compareTo(b.album));
      if(albumSort) {
        songs = songs.reversed.toList();
        albumSort = true;
      }
      albumSort = !albumSort;
      titleSort = false;
      artistSort = false;
    }

    tableBody.children.clear();
    songs.forEach((Song song) {
      TableRowElement row = tableBody.addRow();
      createSongRow(row, song);
    });
  }
}