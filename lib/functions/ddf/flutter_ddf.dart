
// Functions were moved from builder.dart from flutter_markdown dependency (these functions are originally made by NBT), to here for cleaner and more maintainable code
// This is the flutter version of the functions, using flutter widgets


import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:m_flow/dependencies/flutter_markdown/code/code_src/style_sheet.dart';

double getTextWidth(String text, TextStyle style, BuildContext context) {
    // TextPainter: An object that paints a TextSpan tree into a Canvas.
    final TextPainter textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 1,
      textDirection: TextDirection.ltr, // WE CAN USE 'rtl' for arabic & hebrew.
    );

    // Use the context's media query to get the maximum width
    double maxWidth = MediaQuery.of(context).size.width;

    textPainter.layout(minWidth: 0, maxWidth: maxWidth);
    return textPainter.width;
  }


Widget buildTextWithFormatting(String text, TextStyle style, MarkdownStyleSheet styleSheet, BuildContext context) {
    Widget? alignWidget;

    var aIndex = 0;
    if (text.endsWith('w\$')){
      text = text.replaceRange(text.length-2, text.length, '');
      aIndex = 1;
    } else if (text.endsWith('r\$')){
      text = text.replaceRange(text.length-2, text.length, '');
      aIndex = 2;
    }
    // List to hold all the formatted spans (text segments with specific styles)
    final List<InlineSpan> spans = <InlineSpan>[];

    // Start iterating over the characters in the input text
    int i = 0;

    while (i < text.length) {

    if (text[i] == '\\') {
      // Check if the next character is part of a known escape sequence
      if (i + 1 < text.length && (text[i + 1] == '-' || text[i + 1] == '~' || text[i + 1] == '^')) {
        // If yes, treat the next character as a literal
        spans.add(TextSpan(text: text[i + 1], style: style));
        i += 2; // Skip past the escape sequence
      } else {
        // If the backslash is not followed by a known character, treat it as a literal
        spans.add(TextSpan(text: '\\', style: style));
        i += 1; // Move to the next character
      }
    }

    // UNDER TESTING, MAIN BUGS: RANGE ERRORS & NOT COMPATIBLE WHEN USED ALONG WITH OTHER SYNTAXES i.e BOLD/ITALIC/SUB-SUPER SCRIPTS...
    else if (text.contains('^\$')) {
      //print("HEY! it's working.");
      int startIndex = text.indexOf('^\$', i);
      if (startIndex != -1) {
        int endIndex = text.indexOf('^\$', startIndex + 2);
      
      if (endIndex != -1 && (text[startIndex+2] != ' ') && (text[endIndex-1] != ' ')){

      //print("Start: $startIndex");
      //print("End: $endIndex");

      String leftText = text.substring(0, startIndex);
      String centerText = endIndex != -1 ? text.substring(startIndex + 2, endIndex) : text.substring(startIndex + 2);
      String rightText = endIndex != -1 ? text.substring(endIndex+2, text.length) : '';
      //print("LEFT: $leftText");
      //print("Right: $rightText");
      //print("Center: $centerText");


      double availableWidth = MediaQuery.of(context).size.width - 40;
      double leftTextWidth = getTextWidth(leftText, style, context);
      double rightTextWidth = getTextWidth(rightText, style, context);

      double maxCenterTextWidth = availableWidth - leftTextWidth - rightTextWidth;
      double centerTextWidth = maxCenterTextWidth;

      spans.add(WidgetSpan(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(leftText, style: style,),
            ),
            if (centerText.isNotEmpty)
            Expanded(
              child: Container(
                width: centerTextWidth,
                child: Text(
                  centerText,
                  textAlign: TextAlign.center,
                  style: style,
                ),
              ),
            ),
            Expanded(
              child: Text(rightText, style: style,),
            )
          ],
        )
      ));

      i= endIndex != -1 ? endIndex + 2 : text.length;
      } else {

      // If there's a space after the starting '^\$' or before the ending '^\$', treat it as normal text
      spans.add(TextSpan(text: text.substring(startIndex, endIndex != -1 ? endIndex + 2 : text.length), style: style));
      i = endIndex != -1 ? endIndex + 2 : text.length;

      }
      } else {
        // if not starting index found, skip processing
        print("No valid start index found!");
        break;
      }
    } 
    // ENDS HERE------------------------------------------------------------

    // ----------------------------------------------------**CAUTION: 'DO NOT REMOVE THIS'**--------------------------------------------------------------------
    // else if (text.contains('^\$', i)) {
    //   print("Working!");
  
    //   // Find the position of 'c$' after the current index i
    //   int startIndex = text.indexOf('^\$', i);
    //   print("stidx: $startIndex");
    //   int endIndex = text.indexOf('^\$', startIndex + 2);
    //   print("endidx: $endIndex");

    //   // Get the text before and after the 'c$' syntax
    //   final String beforeText = text.substring(i, startIndex);
    //   print("before: $beforeText");
    //   final String centeredText = endIndex != -1 
    //       ? text.substring(startIndex + 2, endIndex) 
    //       : text.substring(startIndex + 2);

    //   // String? centeredText;
    //   // if (endIndex != -1){
    //   //   centeredText = text.substring(startIndex + 2, endIndex);
    //   // } else {
    //   //   centeredText = "No centered text found";
    //   // }
    //   print("center: $centeredText");    
    
    //   final String afterText = endIndex != -1 
    //       ? text.substring(endIndex + 2) 
    //       : '';
    //   print("after: $afterText");

    //   // Add the text before 'c$' as a normal span
    //   if (beforeText.isNotEmpty) {
    //     spans.add(TextSpan(text: beforeText, style: style));
    //   }

    //   // Add the centered text using WidgetSpan
    //   spans.add(WidgetSpan(
    //     child: Container(
    //       alignment: Alignment.center,
    //       width: 550,
    //       // child: Text(centeredText, style: style),
    //       child: Text(centeredText, style: style, maxLines: 2, overflow: TextOverflow.ellipsis),
    //     ),
    //   ));

    //   // Update i to continue processing the text after the last c$
    //   i = endIndex != -1 ? endIndex + 2 : text.length;
    //   // if (endIndex != -1){
    //   //   i = endIndex+2;
    //   // }
    // }
    // ----------------------------------------------------**CAUTION: 'DO NOT REMOVE THIS'**--------------------------------------------------------------------



    else if (text.startsWith('--', i) && (i == 0 || text[i - 1] != '\\')) {
      // Check if the current segment is underlined (enclosed in '-')

      // // if there's a immediate space after '--' then don't apply underline, treat it as normal text...
      // if (i+2 < text.length && text[i+2] == ' '){
      //   i+=2;
      // }
        int j = i + 2;

        // Find the closing '-' to determine the underlined text
        while (j < text.length && !text.startsWith('--', j)) {
          j++;
        }

        if (j < text.length && text[i+2] != ' ' && text[j-1] != ' ') {
          // print('this is: ' + text[j-1]);
          final String underlineText = text.substring(i + 2, j);

          spans.add(TextSpan(
            text: underlineText,
            style: style.copyWith(decoration: TextDecoration.underline),
          ));
          i = j + 2; // Move past the closing '-'
        } else {
          spans.add(TextSpan(text: '--', style: style));
          i += 2;
        }
      }


    // NEW MATHJAX IMPLEMENTATION FOR DYNAMIC-RENDERING, SO FAR IT'S NOT PERFECT, THE MAIN BUG IS THAT, THE LINE IN WHICH MATHJAX IS USED, THAT TEXT WON'T RENDER SUPER, SUB & UNDERLINE....
    else if (text.startsWith('\$\$',i)){//.indexOf('\$\$', i) != -1) {
    print("reached at index: " + i.toString());
      // print('working');
      //print('test');
      //final int startIndex = text.indexOf('\$\$', i); i == startIndex here, since this block isn't called until they are ?
     // final RegExp mathRegExp = RegExp(r'\$\$(.*?)\$\$');
      //final RegExpMatch? match = mathRegExp.firstMatch(text.substring(startIndex));
    //  if (match != null) {
    //    final String mathContent = match.group(1)!;
    
        // Add the text before the math expression, if any (THIS CODE CAUSES THE ABOVE MENTIONED BUG...)
        //if (i < startIndex) {
        //if (i != 0){
        //  spans.add(TextSpan(
        //    text: text.substring(i, startIndex),
        //    style: style.copyWith(fontSize: styleSheet.textScaler?.scale(style.fontSize ?? 16.0) ?? 16.0),
        //  ));
        //}

        // Add the math expression as a WidgetSpan
        var length = text.indexOf('\$\$', i+2);
        if (length != -1){//text.indexOf('\$\$', i+2) != -1){
        var mathJax = text.substring(i+2, length);
       // print(mathJax);
        spans.add(
          WidgetSpan(
            // Credits to NBT leader IMAD for this...
            child: Math.tex(
              //mathContent
              mathJax.replaceAll(' \\ ', ' \\\\ '), textScaleFactor: 1.2),
          ),
        );
        //}
        //i = startIndex + match.end; // Move i to the end of the math expression
        i += (length - (i+2)) + 4;
       // print("LENGTH: " +text.length.toString());
       // print("INDEX: " +i.toString());
      } else {
        spans.add(TextSpan(text: '\$\$', style: style));
        i += 2; // Move i past the two $
      }
    }

    // NEW MATHJAX IMPLEMENTATION ENDS HERE...


      // Check if the current character is a subscript marker '~'
      else if (text.startsWith('~', i)) {
        int j = i + 1;

        // Find the closing '~' to determine the subscript text
        while (j < text.length && text[j] != '~') {
          j++;
        }

        // If a closing '~' is found, apply the subscript formatting
        if (j < text.length  && text[i+1] != ' ' && text[j-1] != ' ') {
          final String subscriptText = text.substring(i + 1, j);

          // Create a WidgetSpan for subscript with a vertical offset
          spans.add(
            WidgetSpan(
              child: Transform.translate(
                offset: Offset(0, styleSheet.textScaler != null ? styleSheet.textScaler!.scale(3.0*2.0) : 3.0), // adjust vertical offset for subscript
                child: Text(
                  subscriptText,
                  textScaler: styleSheet.textScaler,
                  style: style.copyWith(
                    fontSize: style.fontSize! * 0.8, // Slightly smaller font size
                    fontWeight: FontWeight.bold, // Make subscript bold
                  ),
                ),
              ),
            ),
          );
          i = j + 1; // Move the index to the character after the closing '~'
        } else {
          // If no closing '~' is found, treat it as a regular character
          spans.add(TextSpan(text: '~', style: style));
          i++;
        }
       // Check if the current character is a superscript marker '^'
      } else if (text.startsWith('^', i)) {
        int j = i + 1;

        // Find the closing '^' to determine the superscript text
        while (j < text.length && text[j] != '^') {
          j++;
        }

        // If a closing '^' is found, apply the superscript formatting
        if (j < text.length && (text[i+1] != ' ' || text[i+1] != '\$') && (text[j-1] != ' ' || text[j-1] != '\$')) {
          final String superscriptText = text.substring(i + 1, j);

          // Create a WidgetSpan for superscript with a vertical offset
          spans.add(
            WidgetSpan(
              child: Transform.translate(
                offset: Offset(0, styleSheet.textScaler != null ? -styleSheet.textScaler!.scale(3.0*2.0) : -3.0), // adjust vertical offset for superscript
                child: Text(
                  superscriptText,
                  textScaler: styleSheet.textScaler,
                  style: style.copyWith(
                    fontSize: style.fontSize! * 0.7, // Even smaller font size
                    fontWeight: FontWeight.bold, // Make superscript bold
                  ),
                ),
              ),
            ),
          );
          i = j + 1; // Move the index to the character after the closing '^'
        } else {
          // If no closing '^' is found, treat it as a regular character
          spans.add(TextSpan(text: '^', style: style));
          i++;
        }
        // If the current character is neither '~' nor '^', it's regular text
      } else {
        int j = i;
        // Collect all consecutive regular text characters
        //print(text.length);
        while (j < text.length && text[j] != '~' && text[j] != '^' && !text.startsWith('--', j) && text[j] != '\\' && !text.startsWith('\$\$',j)){//text[j] != '\$') {
        //  print(j);
          j++;
        }
       // if (text[j] == '\$'){
        //  j++;
          //if (j < text.length){

          //}
        //}
        //print(text.substring(i,j));
        // Add the regular text to the spans list without any special formatting
     //   if (j < text.length && j != text.length){
     //   if (text[j] != '\$' && text.indexOf('\$\$',j) == -1){
     //     print("reached");
          //print(j)
          //j = max(text.length, j+1);
     //     j++;
     //   }
     //   }
        spans.add(TextSpan(text: text.substring(i, j), style: style.copyWith(fontSize: 
        //styleSheet.textScaler!.scale(style.fontSize ?? 16.0))
        styleSheet.textScaler != null ? styleSheet.textScaler!.scale(style.fontSize ?? 16.0) : 16.0
        ))); // TODO: 16.0 is a const
        i = j; // Move the index to the next character to be processed
        //if (text[j] == '\$'){
        //  i+1;
        //}
        //if (text.indexOf('\$\$',j) == -1){
        //  i+=1;
        //}
      }
    }
    if (aIndex == 1){
      return Center(child: RichText(text: TextSpan(children: spans), textAlign: TextAlign.center,));
    } else if (aIndex == 2){
      return Align(alignment: Alignment.centerRight, child: RichText(text: TextSpan(children: spans), textAlign: TextAlign.end,));
    }
    // Return a RichText widget that displays all the spans with the applied formatting
    return RichText(text: TextSpan(children: spans));
  }