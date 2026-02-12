import 'dart:io';

import 'package:cli/cli.dart' as cli;

const version = '0.0.1';

void main(List<String> arguments) {
  if (arguments.isEmpty|| arguments.first == 'help') {
      printUsage();
  } else if (arguments.first == 'version') {
    print('Current version is $version');
  }else if (arguments.first == 'search'){
      final inputArgs = arguments.length > 1 ? arguments.sublist(1) : null;
      searchWikipedia(inputArgs);
  }else{
      printUsage();
  }
}

void searchWikipedia(List<String>? arguments){
      
      final String articleTitle;

      if(arguments == null || arguments.isEmpty){
          print('Please specify article title as a argument:');

          articleTitle = stdin.readLineSync() ?? '';
      }else{
          articleTitle = arguments.join(' ');
      }
}


void printUsage() {
  print(
    "The following commands are valid: 'help', 'version', 'search <ARTICLE-TITLE>'"
  );
}
