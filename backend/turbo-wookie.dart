#!/usr/bin/env dart

import "package:args/args.dart";
import "lib/turbo-wookie.dart";

/**
 * Kicks everything off.
 * 
 * Deals with some command line args and config stuff then starts the server.
 */
void main(List<String> args) {
  ArgParser parser = _getParser();
  ArgResults results = parser.parse(args);
  
  if(results.command != null && results.command.name == "help") {
    print("Turbo Wookie Usage: ");
    print(parser.getUsage());
    return;
  }
  _printWelcome();

  // Set config info.
  Config.create("config.yaml", forceCreate: results["force-conf"])
    .then((Config config) {
      // Deal with some command line arg settings.
      bool startMPD = results["mpd"];
      int port;
      if(results["port"] != null)
        port = int.parse(results["port"]);
      bool devMode = results["dev"];
      
      // Start the server.
      MPDController mpd = new MPDController.fromConfig(config, startMPD: startMPD);
      new TurboWookieServer.fromConfig(mpd, config, devMode: devMode, port: port);
    });
}

/**
 * Print a nice welcome message.
 */
void _printWelcome() {
  print("Welcome to Turbo Wookie.\n"
        "To interact with mpd, type your command here and press enter.\n");
}

/**
 * Get the command line args parser
 */
ArgParser _getParser() {
  return new ArgParser()
    ..addFlag("dev", abbr: "d", help: "Run the server in dev mode.", defaultsTo: false, negatable: true)
    ..addFlag("mpd", abbr: "m", help: "Start MPD with the server.", defaultsTo: true, negatable: true)
    ..addFlag("force-conf", abbr: "c", help: "Whether or not to force generation of the mpd.conf file.", defaultsTo: false, negatable: true)
    ..addOption("port", abbr: "p", help: "Start the server on this port.")
    ..addCommand("help");
}