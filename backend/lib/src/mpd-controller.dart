part of TurboWookie;

/**
 * Controls MPD.
 */
class MPDController {  
  String ip;
  int controlPort;
  int httpPort;
  String mpdCommand;
  String mpdConfFileDir;
  
  /**
   * Create an [MPDController].
   * 
   * bool startMPD: Whether or not MPD should be started/stopped with the server.
   * bool listenToMPD: Whether or not we should print out MPD's stdin/stderr stream.
   * String ip: MPD's IP.
   * int port: MPD's Port.
   */
  MPDController({this.mpdConfFileDir, bool startMPD: true, bool listenToMPD: true, this.ip: "localhost",
      this.controlPort: 6600, this.httpPort: 8000, this.mpdCommand: "mpd"}) {
    _init(startMPD, listenToMPD);
  }
  
  /**
   * Create an [MPDController] from a [Config] object.
   * Config config: The Config object that will be used to create the controller.
   * bool startMPD: Whether or not MPD should be started/stopped with the server.
   * bool listenToMPD: Whether or not we should print out MPD's stdin/stderr stream.
   */
  MPDController.fromConfig(Config config, {bool startMPD: true, bool listenToMPD: true}) {
    ip = config.mpdDomain;
    controlPort = config.mpdControlPort;
    httpPort = config.mpdHttpPort;
    mpdCommand = config.mpdCommand;
    mpdConfFileDir = config.mpdAbsPath;
    
    _init(startMPD, listenToMPD);
  }
  
  /**
   * Helper function for constructors to initialize a [MPDController].
   */
  void _init(bool startMPD, bool listToMPD) {
    if(startMPD) {
      _startMPD(listToMPD);

      // Capture `Ctr+C` in order to say MPD is closing.
      // MPD closes itself on `Ctr+C`, but it's nice to tell the user.
      ProcessSignal.SIGINT.watch().listen((_) => print("\nClosing MPD"));
    }

    // Listen to the command line to give the user control of MPD.
    stdin.listen((List<int> ints) {
      String command = new String.fromCharCodes(ints).trim();
      cmd(command).then((String data) {
        print(data);
      });
    });
    
  }
  
  /**
   * Start MPD.
   */
  void _startMPD(bool listen) {
    Process.start(mpdCommand, ["--no-daemon", "mpd.conf"], workingDirectory: mpdConfFileDir)
    .then((Process mpd) {
      
      // Print MPD stuff out for us.
      if(listen) {
        mpd.stderr.listen((List<int> ints) {
          print("MPD: ${new String.fromCharCodes(ints)}");
        });
        mpd.stdout.listen((List<int> ints) {
          print("MPD: ${new String.fromCharCodes(ints)}");
        });
      }
      
      // Exit when MPD exits.
      mpd.exitCode.then((int code) {
        print("MPD closed with an exit code of $code");
        exit(code);
      });
      
      // Auto play a random song.
      status().then((Map<String, String> status) {
        if(status["playlistlength"] == "0") {
          addRandom().then((_) {
            play();
          });
        }
      });
      
    });
  }
  
  /**
   * Connect to MPD.
   */
  Future connect() {
    return Socket.connect(ip, controlPort);
  }
  
  /**
   * Watch MPD using the `idle` command.
   */
  Future<Map<String, String>> watcher() {
    return cmd("idle", dataType: "map");
  }
  
  /**
   * Kill MPD using the `kill` command.
   */
  Future<String> kill() {
    return cmd("kill");
  }
  
  Future<String> play({int pos}) {
    if(pos != null)
      return cmd("play $pos");
    else
      return cmd("play");
  }
  
  Future<String> pause() {
    return cmd("pause");
  }
  
  /**
   * Change the song using the `next` command.
   */
  Future<String> next() {
    return cmd("next");
  }
  
  /**
   * Change the song using the `previous` command.
   */
  Future<String> previous() {
    return cmd("previous");
  }
  
  /**
   * Add a song to the playlist, based on a filepath, using the `add` command.
   */
  Future<String> addSong(String filepath) {
    return cmd('add "$filepath"');
  }
  
  Future<Map<String, String>> status() {
    return cmd("status", dataType: "map");
  }
  
  /**
   * Get info about the current song using the `currentsong` command.
   */
  Future<Map<String, String>> currentSong() {
    return cmd("currentsong", dataType: "map");
  }
  
  /**
   * Get a list of upcoming songs through `playlistinfo` and other shenanigans.
   */
  Future<List<Map<String, String>>> upcoming() {
    Completer completer = new Completer();

    // We have to get the current playing song in order to find the playlist
    // position of the current song.
    currentSong().then((Map<String, String> song) {
      // If we aren't playing a song, just send an empty list.
      if(song["Pos"] == null) {
        completer.complete(new List<Map<String, String>>());
        return;
      }
      int pos = int.parse(song["Pos"]);
      
      // Now we can grab the entire playlist.
      cmd("playlistinfo", dataType: "listmap").then((List<Map<String, String>> data) {
        
        // We have to manually take out all the songs that are not up and
        // coming. For some reason, it wouldn't let me remove an element, so I
        // just made a new list and added the relevant songs.
        List<Map<String, String>> upcoming = new List<Map<String, String>>();
        for(int i=0; i < data.length; i++) {
          if(int.parse(data[i]["Pos"]) > pos) {
            upcoming.add(data[i]);
          }
        }
        
        // Finally done.
        completer.complete(upcoming);
      });
    });
    
    return completer.future;
  }
  
  /**
   * Get a list of all artists, using the `list` command.
   */
  Future<List<String>> artists() {
    return cmd("list artist", dataType: "list");
  }
  
  /**
   * Get a list of albums, using the `list` command.
   */
  Future<List<String>> albums([String artist]) {
    if(artist != null)
      return cmd('list album artist "$artist"', dataType: "list");
    else
      return cmd("list album", dataType: "list");
  }
  
  /**
   * Get a list of songs, using the `find` command.
   */
  Future<List<Map<String, String>>> songs([String artist, String album]) {
    if(artist != null && album != null)
      return cmd('find artist "$artist" album "$album"', dataType: "listmap");
    else if(artist != null && album == null)
      return cmd('find artist "$artist"', dataType: "listmap");
    else
      return cmd('listallinfo "/"', dataType: "listmap");
  }
  
  /**
   * Add a random song.
   * 
   * This will append a random song to the end of the playlist.
   */
  Future<Map<String, String>> addRandom() {
    Completer completer = new Completer();
    
    songs().then((List<Map<String, String>> songs) {
      Random rnd = new Random();
      Map<String, String> song = songs[rnd.nextInt(songs.length)];
      addSong(song["file"]).then((_) {
        completer.complete(song);
      });
    });
    
    return completer.future;
  }
  
  /**
   * Play a random song.
   * 
   * This will append a random song to the end of the playlist and play it if
   * nothing is already playing.
   */
  Future<Map<String, String>> playRandom() {
    Completer comleter = new Completer();
    
    status().then((Map<String, String> status) {
      if(status["state"] != "play") {
        int pos = int.parse(status["playlistlength"]);
        addRandom().then((Map<String, String> song) {
          play(pos: pos);
          comleter.complete(song);
        });
      }
    });
    
    return comleter.future;
  }
  
  /**
   * Perform a request on MPD.
   * 
   * String request: The request string.
   * String dataType: The type of data to recieve. By default a String is returned.
   * String newKey: If you are receiving a list of maps, this is the key that defines a new item in the list.
   */
  Future cmd(String request, {String dataType: "string", String newKey: "file"}) {
    Completer completer = new Completer();
    String dataStr = "";
    
    // We have to connect every time, otherwise MPD doesn't return anything
    // after the first request.
    connect()
      .then((Socket socket) {
        // Send MPD our request with a new line attached at the end.
        socket.write("$request\n");
        
        // Gather our data when we get it.
        socket.listen((List<int> ints) {
          dataStr += new String.fromCharCodes(ints);
          if(_atEnd(dataStr))
            socket.close();
        },
        onDone: () {
          // Data is some sort of JSON type thing (Map/List).
          var data;
          
          // Turn the string into some real structured data.
          if(dataType == "map")
            data = _strToMap(dataStr);
          else if(dataType == "list")
            data = _strToList(dataStr);
          else if(dataType == "listmap")
            data = _strToListMap(dataStr, newKey);
          else
            data = dataStr;

          // We're done.
          completer.complete(data);
        });
      });
    
    return completer.future;
  }
  
  /**
   * Check if we are at the end of an MPD response.
   */
  bool _atEnd(String str) {
    // If it was successful, MPD will send us an OK message, otherwise,
    // it will send us an error that looks like: `ACK [50@0]`.
    return str.endsWith("OK\n") || 
        str.contains(new RegExp("ACK \[[0-9]?([0-9])@[0-9]?([0-9])\]"));
  }
  
  /**
   * Turn a response String from MPD into a Map<String, String>.
   */
  Map<String, String> _strToMap(String str) {
    Map<String, String> data = new Map<String, String>();
    for(String line in str.split("\n")) {
      List<String> kv = line.split(":");
      if(kv.length > 1)
        data[kv[0]] = kv[1].trim();
    }
    
    return data;
  }
  
  /**
   * Turn a response String from MPD into a List<String>
   */
  List<String> _strToList(String str) {
    List<String> data = new List<String>();
    for(String line in str.split("\n")) {
      List<String> kv = line.split(":");
      if(kv.length > 1)
        data.add(kv[1].trim());
    }
    
    return data;
  }
  
  /**
   * Turn a response String from MPD into a List<Map<String, String>>.
   */
  List<Map<String, String>> _strToListMap(String str, String newKey) {
    List<Map<String, String>> data = new List<Map<String, String>>();
    
    for(String line in str.split("\n")) {
      List<String> kv = line.split(":");
      if(kv.length > 1) {
        if(kv[0] == newKey)
          data.add(new Map<String, String>());
        if(data.isNotEmpty)
          data.last[kv[0]] = kv[1].trim();
      }
    }

    return data;
  }
}