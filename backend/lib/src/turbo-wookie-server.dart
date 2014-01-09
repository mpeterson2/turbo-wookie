part of TurboWookie;


/**
 * Sends and receives information from the Turbo Wookie client.
 */
class TurboWookieServer {  
  String fileDir;
  String ip;
  int port;
  MPDController mpd;
  String turboWookieDirectory;
  
  /**
   * Create a new [TurboWookieServer].
   * 
   * MPDController mpd: The MPD controller for the server to interact with.
   * String turboWookieDirectory: The absolute path to the main Turbo Wookie Directory.
   * String ip: The IP to bind to. Default = localhost.
   * int port: The Port to run on. Default = 9000.
   * bool devMode: If true: server dart files, if false: server javascript files. Default = false.
   */
  TurboWookieServer(this.mpd, this.turboWookieDirectory, 
      {this.ip: "localhost", this.port: 9000, bool devMode: false}) {
    _init(devMode);
  }
  
  /**
   * Create an [TurboWookieServer] from a [Config] object.
   * MPDController mpd: The MPD controller for the server to interact with.
   * Config config: The Config object that will be used to create the controller.
   * int port: The port the server will run on. If not specified, it will get this from the config.
   * bool devMode: If true: server dart files, if false: server javascript files. Default = false. 
   */
  TurboWookieServer.fromConfig(this.mpd, Config config, {this.port, bool devMode: false}) {
    ip = config.serverDomain;
    if(port == null)
      port = config.serverPort;
    turboWookieDirectory = config.turboWookieDirectory;
    _init(devMode);
  }
  
  /**
   * Helper function for constructors to Initialize a [TurboWookieServer].
   */
  void _init(bool devMode) {
    HttpServer.bind(ip, port)
      .then((HttpServer server) {
        Router router = new Router(server)

        ..serve("/stream").listen(_stream)
        ..serve("/current").listen(_current)
        ..serve("/upcoming").listen(_upcoming)
        ..serve("/artists").listen((_artists))
        ..serve("/albums").listen((_albums))
        ..serve("/songs").listen(_songs)
        ..serve("/add").listen(_add)
        ..serve("/polar").listen(_polar) // TODO This isn't threaded, so only 1 person gets it.
        ..defaultStream.listen(_serveFile);
      });
    
    if(devMode)
      fileDir = "${turboWookieDirectory}/frontend/web";
    else
      fileDir = "${turboWookieDirectory}/frontend/build";
      print(fileDir);
      
    // Force MPD to play a random song if there is no song already playing.
    _watchMPD();
  }
  
  /**
   * Watch MPD to be sure it plays a random song whenever no song is playing.
   * 
   * This method will call itself when it receives an update from MPD.
   */
  void _watchMPD() {
    mpd.watcher().then((Map<String, String> watch) {
      if(watch["changed"] == "player") {
        mpd.playRandom();
      }
    })
    // When we finish watching, watch again.
    .whenComplete(_watchMPD);
  }
  
  /**
   * Serve a file to the client.
   */
  void _serveFile(HttpRequest request) {
    String uri = request.uri.path;
    
    // If the '/' is requested, give them the index file.
    if(uri == "/")
      uri = "/index.html";
    
    // Give the file to the client.
    File file = new File(fileDir + uri);
    file.exists().then((bool found) {
      if(found) {
        // Set the mimetype
        List<String> mime = mimeType(uri.substring(uri.lastIndexOf(".") + 1));
        request.response.headers.contentType = new ContentType(mime[0], mime[1]);
        
        // Write the file to the client.
        file.openRead().pipe(request.response);
      }
      // Send a 404 if the file doesn't exist.
      else {
        request.response.statusCode = HttpStatus.NOT_FOUND;
        request.response.close();
      }
    });
  }
  
  /**
   * Stream to the client.
   */
  void _stream(HttpRequest request) {
    request.response.redirect(new Uri(host: mpd.ip, port: mpd.httpPort), status: HttpStatus.FOUND);
    request.response.close();   
  }
  
  /**
   * The the client info about the currently playing song.
   */
  void _current(HttpRequest request) {
    try {
      mpd.currentSong().then((Map<String, String> data) {
        _respond(request, data);
      });
    } catch(exception) {
      print(exception);
    }
  }
  
  /**
   * Tell the client what songs are coming in the playlist.
   */
  void _upcoming(HttpRequest request) {
    try {
      mpd.upcoming().then((List<Map<String, String>> data) {
        _respond(request, data);
      });
    } catch(exception) {
      print(exception);
    }
  }
  
  /**
   * Tell the client all the artist names in the library.
   */
  void _artists(HttpRequest request) {
    try {
      mpd.artists().then((List<String> data) {
        _respond(request, data);
      });
    } catch(exception) {
      print(exception);
    }
  }
  
  /**
   * Tell the client all the albums in the library.
   * Can be filtered by artist.
   */
  void _albums(HttpRequest request) {
    try {
      String artist = request.uri.queryParameters["artist"];
      if(artist != null)
        artist = artist.trim();
      
      mpd.albums(artist).then((List<String> data) {
        _respond(request, data);
      });
    } catch(exception) {
      print(exception);
    }
  }
  
  /**
   * Tell the client all the songs in the library.
   * Can be filtered by artist and album.
   */
  void _songs(HttpRequest request) {
    try {
      String artist = request.uri.queryParameters["artist"];
      String album = request.uri.queryParameters["album"];
      if(artist != null)
        artist = artist.trim();
      if(album != null)
        album = album.trim();
      
      mpd.songs(artist, album).then((List<Map<String, String>> data) {
        _respond(request, data);
      });
    } catch(exception) {
      print(exception);
    }
  }
  
  /**
   * Add a song the client wants based on it's filepath.
   */
  void _add(HttpRequest request) {
    try {
      String filepath = request.uri.queryParameters["song"].trim();
      mpd.addSong(filepath);
      request.response.close();
    } catch(exception) {
      print(exception);
    }
  }
  
  /**
   * Tell the client when something updates.
   */
  void _polar(HttpRequest request) {
    mpd.watcher().then((Map<String, String> data) {
      _respond(request, data);
    });
  }
  
  /**
   * Helper function to respond to the client using JSON data.
   */
  void _respond(HttpRequest request, var data) {
    try {
      request.response.headers.contentType = new ContentType("application", "json");
      request.response.write(JSON.encode(data));
      request.response.close();
    } catch(exception) {
      print(exception);
    }
  }
  
}