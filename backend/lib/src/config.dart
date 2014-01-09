part of TurboWookie;

/**
 * A file that holds config info about Turbo Wookie.
 */
class Config {  
  YamlMap _map;
  
  int serverPort;
  String mpdCommand;
  String mpdDomain;
  String serverDomain;
  int mpdHttpPort;
  int mpdControlPort;
  String turboWookieDirectory;
  String mpdSubDirectory;
  String mpdAbsPath;
  String mpdMusicDirectory;
  String mpdPlaylistDirectory;
  String mpdDBFile;
  String mpdLogFile;
  String mpdPidFile;
  String mpdStateFile;
  String mpdStickerFile;
  
  bool _confExisted;
  
  /**
   * Private constructor.
   */
  // It must be private because file operations are asynchronous, and
  // constructors cannot return Futures.
  Config._construct(String yaml) {
    // Create the YamlMap using the yaml library, then set all the values.
    _map = loadYaml(yaml);
    _setValues();
  }
  
  /**
   * Create a [Config] object.
   * 
   * String path: The path to the yaml file.
   * bool forceCreate: Forces the generated files (not directories) to
   *      regenerate, even if they already exist. This should happen if
   *      the `modHttpPort` changes in the `config.yaml` file.
   */
  static Future<Config> create(String path, {bool forceCreate: false}) {
    Completer completer = new Completer();
    File file = new File(path);
    file.exists().then((bool exists) {
      if(exists) {
        String yaml = "";
        file.openRead().listen((List<int> ints) {
          // Add the contents of the file to our yaml string.
          yaml += new String.fromCharCodes(ints);
        }).onDone(() {
          // Create our config object.
          Config config = new Config._construct(yaml);
          // Create our files.
          config._createFiles(force: forceCreate).whenComplete(() {
            completer.complete(config);            
          });
        });
      }
    });
    
    return completer.future;
  }
  
  /**
   * Set all the config values.
   */
  void _setValues() {
    serverPort = _map["server_port"];
    mpdCommand = _map["mpd_command"];
    mpdDomain = _map["mpd_domain"];
    serverDomain = _map["server_domain"];
    mpdHttpPort = _map["mpd_http_port"];
    mpdControlPort = _map["mpd_control_port"];
    mpdSubDirectory = _map["mpd_subdirectory"];
    mpdMusicDirectory = _map["mpd_music_directory"];
    mpdPlaylistDirectory = _map["mpd_playlist_directory"];
    mpdDBFile = _map["mpd_db_file"];
    mpdLogFile = _map["mpd_log_file"];
    mpdPidFile = _map["mpd_pid_file"];
    mpdStateFile = _map["mpd_state_file"];
    mpdStickerFile = _map["mpd_sticker_file"];
    
    // Find the Turbo Wookie project path.
    String twd = Platform.script.path;
    twd = twd.substring(0, twd.lastIndexOf("/")); //backend folder.
    turboWookieDirectory = twd.substring(0, twd.lastIndexOf("/"));
    
    // Set the mpd absolute path
    mpdAbsPath = "$turboWookieDirectory/$mpdSubDirectory";
  }
  
  /**
   * Generate all the MPD related files.
   * 
   * bool force: Force the files to generate even if they already exist.
   */
  Future _createFiles({bool force: false}) {
    // We have to add all our futures to this list, so that we know when all
    // the futures have finished.
    List<Future> futures = new List<Future>();
    
    // Create files.
    futures.add(_createFile(mpdDBFile, force));
    futures.add(_createFile(mpdLogFile, force));
    futures.add(_createFile(mpdPidFile, force));
    futures.add(_createFile(mpdStateFile, force));
    futures.add(_createFile(mpdStickerFile, force));
    
    // Create directories.
    futures.add(_createDirectory(mpdMusicDirectory));
    futures.add(_createDirectory(mpdPlaylistDirectory));
    
    // Create `mpd.conf`.
    Future conf = _createFile("mpd.conf", force);
    futures.add(conf);
    conf.then((File file) {
      // If the conf file didn't already exist, or we're force writing it,
      // write to the file.
      if(!_confExisted || force)
        futures.add(_createConf(file));
    });
    
    // Will wait for all the futures in the list to end before completing.
    return Future.wait(futures);
  }
  
  /**
   * Helper function to create a directory in the mpd path.
   */
  Future<Directory> _createDirectory(String name) {
    Completer completer = new Completer();
    Directory dir = new Directory("$mpdAbsPath/$name");
    dir.exists().then((bool exists) {
      if(exists) {
        // If it exists, we're already done.
        completer.complete(dir);
      }
      else {
        // Create it and complete it.
        dir.create().whenComplete(() {
          completer.complete(dir);
        });
      } 
    });
    
    return completer.future;
  }
  
  /**
   * Helper function to create a file in the mpd path.
   */
  Future<File> _createFile(String name, bool force) {
    Completer completer = new Completer();
    File file = new File("$mpdAbsPath/$name");
    file.exists().then((bool exists) {
      // If it's the `mpd.conf` file, we need to specify whether it previously
      // existed or not for later.
      if(name == "mpd.conf") {
        _confExisted = exists;
      }
      
      // If it already existed, and we aren't forcing, we're done.
      if(exists && !force) {
        completer.complete();
      }
      
      // If we are forcing: delete it and recreate it.
      else if(exists && force) {
        file.delete().whenComplete(() {
          file.create().whenComplete(() {
            completer.complete(file);
          });
        });
      }
      
      // If it doesn't exist: create it.
      else {
        file.create().whenComplete(() {
          completer.complete(file);
        });
      }
    });
    
    return completer.future;
  }
  
  /**
   * Write to the `mpd.conf` file.
   */
  Future<File> _createConf(File file) {
    // The contents of the file.
    String contents = """
music_directory     "$mpdAbsPath/$mpdMusicDirectory"
playlist_directory  "$mpdAbsPath/$mpdPlaylistDirectory"
db_file             "$mpdAbsPath/$mpdDBFile"
log_file            "$mpdAbsPath/$mpdLogFile"
pid_file            "$mpdAbsPath/$mpdPidFile"
state_file          "$mpdAbsPath/$mpdStateFile"
sticker_file        "$mpdAbsPath/$mpdStickerFile"
audio_output {
  type              "httpd"
  name              "My HTTP Stream"
  encoder           "vorbis"    # optional, vorbis or lame
  port              "$mpdHttpPort"
  bind_to_address   "0.0.0.0"   # optional, IPv4 or IPv6
  ##  quality       "5.0"     # do not define if bitrate is defined
  bitrate           "128"     # do not define if quality is defined
  format            "44100:16:1"
  max_clients       "0"     # optional 0=no limit
}
""";
    
    // Write the contents to the file (Somehow this is synchronous?).
    file.openWrite().write(contents);
  }
}