// markdown_to_pdf MIT licensed | Copyright (c) 2022 Datagrove | Github link: https://github.com/datagrove/markdown_to_pdf/tree/main?tab=readme-ov-file

// This file was modified by Native Bits Team. ////////

//import 'dart:developer';
//import 'dart:convert';
//import 'dart:collection';
import 'dart:async';
//import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
//import 'package:flutter/material.dart';
//import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/widgets.dart' as w;
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:html/parser.dart';
import 'package:html/dom.dart';
import 'package:m_flow/dependencies/dart_pdf/pdf/code/src/widgets/text.dart';
import 'package:m_flow/dependencies/flutter_markdown/code/code_src/style_sheet.dart';
//import 'package:m_flow/dependencies/flutter_markdown/code/code_src/builder.dart' as b;
//import 'package:pdf/widgets.dart' as pw;
import 'package:markdown/markdown.dart' as md;
//import 'package:m_flow/dependencies/markdown/code/markdown.dart' as md;

//import 'package:pdf/pdf.dart' as p;
//import 'package:pdf/pdf.dart';
import 'package:http/http.dart' as http;
import 'package:m_flow/functions/json_db.dart';
import 'package:printing/printing.dart';
//import 'package:pdf/widgets.dart';

import 'package:m_flow/dependencies/dart_pdf/pdf/code/pdf.dart';
import 'package:m_flow/dependencies/dart_pdf/pdf/code/pdf.dart' as p;
import 'package:m_flow/dependencies/dart_pdf/pdf/code/widgets.dart' as pw;


import 'package:screenshot/screenshot.dart';
import 'package:m_flow/functions/ddf/pdf_ddf.dart';

// computed style is a stack, each time we encounter an element like <p>... we push its style onto the stack, then pop it off at </p>
// the top of the stack merges all of the styles of the parents.
class ComputedStyle {
  List<Style> stack = [Style()];
  push(Style s, e) {
    var base = stack.last;
    s = s;
    s.e = e;
    stack.add(s.merge(base));
  }

  pop() {
    stack.removeLast();
  }

  pw.TextStyle style() {
    return stack.last.style();
  }

  Style parent() {
    return stack[stack.length - 1];
  }

  // Style parent2() {
  //   return stack[stack.length - 2];
  // }
}

Future<Uint8List> getImage(imageUrl) async {
  final formatUrl = Uri.parse(imageUrl);
  var url = Uri.https(formatUrl.host, formatUrl.path);
  var response = await http.get(url);
  final bytes = response.bodyBytes;
  return bytes;
}


Future<Uint8List> getImageNBT(imageUrlNBT) async {
imageUrlNBT = imageUrlNBT.toString().replaceFirst("file:///", "");
  if (imageUrlNBT.toString().startsWith("http")){
    return getImage(imageUrlNBT); 
  } else {
return File(imageUrlNBT).readAsBytes(); // [TRANSPARENCY] I got this from developer Madhur, who said to have got it from a snippit of code he wrote
  }
}

class _UrlText extends pw.StatelessWidget {
  _UrlText(this.text, this.url);

  final String text;
  final String url;

  @override
  pw.Widget build(pw.Context context) {
    return pw.UrlLink(
      destination: url,
      child: pw.Text(text,
          style: const pw.TextStyle(
            decoration: pw.TextDecoration.underline,
            decorationColor: PdfColors.blue,
            color: PdfColors.blue,
          )),
    );
  }
}

// you will need to add more attributes here, just follow the pattern.
class Style {
  pw.Font? font;
  pw.FontWeight? weight;
  double? height;
  pw.FontStyle? fontStyle;
  pw.UrlLink? urlLink;
  p.PdfColor? color;
  int listNumber = 0;
  pw.Container? container;
  int? listIndent;
  pw.Widget? bullet;
  pw.TextDecoration? textDecoration;
  pw.BoxDecoration? boxDecoration;
  Node? e;
  Style(
      {this.font,
      this.weight,
      this.height,
      this.fontStyle,
      this.color,
      this.bullet,
      this.container,
      this.listIndent = 0,
      this.listNumber = 0,
      this.e,
      this.textDecoration,
      this.boxDecoration});

  Style merge(Style s) {
    font ??= s.font;
    weight ??= s.weight;
    height ??= s.height;
    fontStyle ??= s.fontStyle;
    color ??= s.color;
    container ??= s.container;
    bullet ??= s.bullet;
    textDecoration ??= s.textDecoration;
    boxDecoration ??= s.boxDecoration;
    return this;
  }

  pw.TextStyle style() {
    return pw.TextStyle(
        font: font,
        fontWeight: weight,
        fontSize: height,
        color: color,
        fontStyle: fontStyle,
        decoration: textDecoration,
        background: boxDecoration);
  }
}

class BorderStyle {
  const BorderStyle({
    this.paint = true,
    this.pattern,
    this.phase = 0,
  });

  static const none = BorderStyle(paint: false);
  static const solid = BorderStyle();
  static const dashed = BorderStyle(pattern: <int>[3, 3]);
  static const dotted = BorderStyle(pattern: <int>[1, 1]);

  /// Paint this line
  final bool paint;

  /// Lengths of alternating dashes and gaps. The numbers shall be nonnegative
  /// and not all zero.
  final List<num>? pattern;

  /// Specify the distance into the dash pattern at which to start the dash.
  final int phase;
}

// each node is formatted as a chunk. A chunk can be a list of widgets ready to format, or a series of text spans that will be incorporated into a parent widget.
class Chunk {
  List<pw.Widget>? widget;
  pw.TextSpan? text;
  Chunk({this.widget, this.text});
}

// post order traversal of the html tree, recursively format each node.
class Styler {
  var style = ComputedStyle();

  get text => null;

  Future<Chunk> formatStyle(Node e, Style s) async {
    style.push(s, e);
    var o = await format(e);
    style.pop();
    return o;
  }

  Future<List<pw.Widget>> widgetChildren(Node e, Style s) async {
    style.push(s, e);
    List<pw.Widget> r = [];
    List<pw.TextSpan> spans = [];
    clear({TextAlign align = TextAlign.start }) {
      if (spans.isNotEmpty) {
           // if (e.text!.endsWith('w\$')){align = TextAlign.center;}
        // turn text into widget
        if (align == TextAlign.center){
        r.add(pw.Center(child:pw.RichText(text: pw.TextSpan(children: spans)))); // [TRANSPARENCY] I got the idea from REF #2
        } else if(align == TextAlign.end){
          r.add(pw.Align(alignment: pw.Alignment.centerRight, child: pw.RichText(text: pw.TextSpan(children: spans))));
        }
        else {
          r.add(pw.RichText(text: pw.TextSpan(children: spans)));
        }
        //print(align);
        spans = [];
      }
    }
    var alignment = TextAlign.start;
    for (var o in e.nodes) {
      var ch = await format(o);
      if (ch.widget != null) {
        clear();
        r = [...r, ...ch.widget!];
      } else if (ch.text != null) {
        pw.FontWeight fw = pw.FontWeight.normal;
        double fontSize = 16;
      //  if (s.bullet != null){ // NBT
       //   if (ch.text!.text == "\n"){ // NBT
         //   continue; // NBT
         // } // 
         if (ch.text!.text != null && ch.text!.text != '' && ch.text!.text != "\n"){
          if (e.nodeType == Node.ELEMENT_NODE){
            var k = e as Element;
            if (k.localName!.startsWith('h')){
              fw = pw.FontWeight.bold;
              fontSize = 24 - double.parse(k.localName!.substring(1)) * 2;
            }
          }
          if (ch.text!.text!.endsWith('w\$')){alignment = TextAlign.center;ch.text = pw.TextSpan(text: ch.text!.text!.replaceRange(ch.text!.text!.length-2, ch.text!.text!.length, ''), style: ch.text!.style!.copyWith(fontWeight: fw, fontSize: fontSize));
          } else if (ch.text!.text!.endsWith('r\$')){
            alignment = TextAlign.end;
            ch.text = pw.TextSpan(text: ch.text!.text!.replaceRange(ch.text!.text!.length-3, ch.text!.text!.length, ''), style: ch.text!.style!.copyWith(fontWeight: fw, fontSize: fontSize)); // REF #UK
          }
          spans.add(ch.text!); // [T] REF #MD
          print(ch.text!.text);
          }
        //ch.text = pw.TextSpan(text: ch.text!.text, style: ch.text!.style != null ? ch.text!.style!.copyWith(background: pw.BoxDecoration(color: PdfColor(1.0,0.0,0.0))) : pw.TextStyle(background: pw.BoxDecoration(color: PdfColor(1.0,0.0,0.0)))); // [T] REF #UK
          //spans.add(pw.TextSpan(text: ch.text!.text!.replaceAll("\n", ""))); // This was added to fix a "bug" that causes a newline to be added causing text not to be next to the "bullet"
          //spans.add(const pw.TextSpan(text: "\n\n")); // 
          //continue; // 
       // } //
        //ch.text = pw.TextSpan(text: ch.text!.text, style: ch.text!.style!.copyWith(height: )); // NBT
        //spans.add(ch.text!); // REF #MD NBT
      }
    }
    clear(align: alignment);
    style.pop();
    return r;
  }

  Future<pw.TextSpan> inlineChildren(Node e, Style s) async {
    style.push(s, e);
    List<pw.InlineSpan> r = [];
    for (var o in e.nodes) {
      var ch = await format(o);
      if (ch.text != null) {
        r.add(ch.text!);
      }
    }
    style.pop();
    return pw.TextSpan(children: r);
  }

  pw.TextStyle? s;
  pw.Divider? f;

  // I only implmenented necessary ones, but follow the pattern

  int i = 0;

  Future<Chunk> format(Node e) async {
    switch (e.nodeType) {
      case Node.TEXT_NODE:
// NBT Starts | Credits to Madhur | Modified by Imad
if (e.text!.contains(r'\$') || e.text!.contains(r'$$')) {
        if (e.text!.startsWith(r'$$') ){// && e.text!.endsWith(r'$$')) {
          if (e.text!.endsWith(r'$$' + "r\$")){
          // Block math expression
          return Chunk(widget: [pw.Align(alignment: pw.Alignment.centerRight,child: pw.Image(pw.MemoryImage(await ScreenshotController().captureFromWidget(Math.tex(e.text!.replaceAll(r'$$', '').replaceAll('r\$', ''),textStyle: const TextStyle(fontSize: 16, color: Color.fromARGB(255, 255, 255, 255)))))))]); // Check NBT # 1 below | Copy Pasted
          //return Chunk(widget: [pw.Image(pw.MemoryImage(await ScreenshotController().captureFromWidget(Math.tex(e.text!.replaceAll(r'$$', ''),textStyle: const TextStyle(fontSize: 16, color: Color.fromARGB(255, 255, 255, 255))))))]); // Check NBT # 1 below
          } else if (e.text!.endsWith(r'$$' + 'w\$')){
            return Chunk(widget: [pw.Center(child: pw.Image(pw.MemoryImage(await ScreenshotController().captureFromWidget(Math.tex(e.text!.replaceAll(r'$$', '').replaceAll('w\$', ''),textStyle: const TextStyle(fontSize: 16, color: Color.fromARGB(255, 255, 255, 255)))))))]); // Check NBT # 1 below | Copy Pasted
          }
        } else {
          // Inline math expression
          final parts = e.text!.split(r'$');
          for (int i = 0; i < parts.length; i++) {
            if (i % 2 == 0) {
              //widgets.add(MarkdownBody(data: parts[i],styleSheet: style,));
              return Chunk(text: pw.TextSpan(baseline: 0, style: style.style(), text: parts[i])); // [TRANSPARENCY] Got it from normal return below
            } else {
              //widgets.add(Math.tex(parts[i],textStyle: TextStyle(fontSize: 16),));
              if (e.text!.endsWith("r\$")){
              return Chunk(widget: [pw.Align(alignment: pw.Alignment.centerRight, child:pw.Image(pw.MemoryImage(await ScreenshotController().captureFromWidget(Math.tex(e.text!.replaceAll('r\$', ''),textStyle: const TextStyle(fontSize: 16, color: Color.fromARGB(255, 255, 255, 255)))))))]); // Copy Pasted
              } else if (e.text!.endsWith("w\$")){
                return Chunk(widget: [pw.Center(child:pw.Image(pw.MemoryImage(await ScreenshotController().captureFromWidget(Math.tex(e.text!.replaceAll('w\$', ''),textStyle: const TextStyle(fontSize: 16, color: Color.fromARGB(255, 255, 255, 255)))))))]); // Copy Pasted
              }
              //return Chunk(widget: [pw.Image(pw.MemoryImage(await ScreenshotController().captureFromWidget(Math.tex(e.text!,textStyle: const TextStyle(fontSize: 16, color: Color.fromARGB(255, 255, 255, 255))))))]); // Copy Pasted it from above
            }
          }
        }
    }
    //b.MarkdownBuilder().buildTextWithFormatting(text, style, styleSheet);
    //b.buildTextWithFormatting(e.text!, style.style())

    if (e.text!.contains('~') || e.text!.contains('^') || e.text!.contains('--')){//')){
      return Chunk(widget: [buildTextWithFormatting//PDF
      (e.text ?? "", style.style().copyWith(fontSize: 16), MarkdownStyleSheet())]);
    }

    pw.FontWeight fw = pw.FontWeight.normal;
    double fontSize = 28;
    //if (e.text!.endsWith('ww\$')){
      if (e.parentNode!.nodeType == Node.ELEMENT_NODE){
        var k = e.parentNode as Element;
        if (k.localName!.startsWith('h')){
          fw = pw.FontWeight.bold;
          fontSize = 26.0 - int.parse(k.localName!.substring(1))*2; // [TRANSPARENCY] Ref #3
        }
      }
      if (e.text!.endsWith("r\$")){
      e.text = e.text!.replaceRange(e.text!.length-3, e.text!.length, '');
      return Chunk(widget: [pw.Align(alignment: pw.Alignment.centerRight,child: pw.RichText(text: pw.TextSpan(text: e.text, style: pw.TextStyle(fontSize: fontSize, fontWeight: fw)), textAlign: pw.TextAlign.end))]);


    } else
    if (e.text!.endsWith('w\$')){
      //print("t");
      //print(await widgetChildren(e, Style()));
      //return Chunk(widget: await widgetChildren(e, Style())); // [TRANSPARENCY] Ref #1


      e.text = e.text!.replaceRange(e.text!.length-2, e.text!.length, '');
      return Chunk(widget: [pw.Center(child: pw.RichText(text: pw.TextSpan(text: e.text, style: pw.TextStyle(fontSize: fontSize, fontWeight: fw)), textAlign: pw.TextAlign.center))]);


      //e.text = e.text!.replaceRange(e.text!.length-2, e.text!.length, '');
      //return Chunk(widget: [pw.Center(child:pw.RichText(text: pw.TextSpan(baseline: 0, style: style.style(), text: (e.text))))]);
    }
// NBT ENDS
        return Chunk(
            text:
                pw.TextSpan(baseline: 0, style: style.style(), text: (e.text)));
      case Node.ELEMENT_NODE:
        e as Element;
        // for (var o in e.attributes.entries) { o.key; o.value;}
        switch (e.localName) {
          // SPANS
          // spans can contain text or other spans
          case "span":
          // case "code":
          //   return Chunk(text: inlineChildren(e, Style()));
          case "code":
            return Chunk(
                text: await inlineChildren(
                    e,
                    Style(
                        boxDecoration: const pw.BoxDecoration(
                          color: PdfColors.grey200,
                          borderRadius:
                              pw.BorderRadius.all(pw.Radius.circular(3)),
                        ),
                        font: pw.Font.courier())));
          case "strong":
            return Chunk(
                text: 
                await inlineChildren(e, Style(weight: pw.FontWeight.bold)));
          case "em":
            return Chunk(
                text: await inlineChildren(
                  e, Style(fontStyle: pw.FontStyle.italic)));
          case "a":
            return Chunk(
                widget: [_UrlText((e.innerHtml), (e.attributes["href"]!))]);
          case "del":
            return Chunk(
                text: await inlineChildren(
                    e,
                    Style(
                        color: PdfColors.black,
                        textDecoration: pw.TextDecoration.lineThrough)));

          // blocks can contain blocks or spans
          case "ul":
          case "ol":
            int ln;
            final cl = e.attributes["start"];
            if (cl != null) {
              ln = int.parse(cl) - 1;
            } else {
              ln = 0;
            }
            return Chunk(
                widget: await widgetChildren(
                    e,
                    Style(
                      bullet: e.localName == "ul" ? pw.Bullet() : null,
                      listIndent: style.stack.last.listIndent ?? -4 + 4,
                      listNumber: ln,
                    )));
          // listNumber: e.attributes["start"] == null
          //     ? 0
          //     : int.parse(e.attributes["start"]!))));
          case "hr":
            return Chunk(widget: [pw.Divider()]);
          case "li":
            // we don't need to given an indent because we'll indent the child tree
            final st = style.stack.last;
            final bullet =
                st.bullet ?? pw.Text("${++style.parent().listNumber}");
            final wl = await widgetChildren(e, Style());
            print(wl);
            print(e.text);
         /*   print(wl); // NBT
            //if (wl.first.runtimeType == pw.RichText){
            //  print(((wl.first as pw.RichText).text as pw.TextSpan).text);
            //}
            var list = [];
            var index = 0;
            wl.forEach((object){
//              var list = [];
              if (object.runtimeType == pw.RichText){
                if (((object as pw.RichText).text as pw.TextSpan).text != null){
                  //wl.remove(object);
                  list.add(index);
                }
              }
              index +=1;
            });
            for (var indexC in list.reversed) { // [T] REF #Re reversed Desc
              //list.remove(value)
              //list.removeAt(index);
              wl.removeAt(indexC); // [T] Above
            }
            //list.reversed.forEach((v){ // REF #Re
              //list.removeAt(v);
            //});
            print(e.text);*/ // NBT END
            final w = pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: <pw.Widget>[
                  pw.SizedBox(width: 20, height: 20, child: bullet), // C UN C
                  pw.Expanded(
                      child: pw.Padding( // NBT C UN C
                          padding: const pw.EdgeInsets.only(left: 10), // NBT C UN C
                          child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              //mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, // NBT
                              children:wl))) //wl))//) NBT C UN C EDIT
                              //[wl[1]]))
                ]);
            return Chunk(widget: [w]);
          case "blockquote":
            return Chunk(widget: [
              pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: <pw.Widget>[
                    pw.Container(
                      decoration: const pw.BoxDecoration(
                          border: pw.Border(
                              left: pw.BorderSide(
                                  color: p.PdfColors.grey400, width: 2)),
                          color: p.PdfColors.grey200),
                      padding:
                          const pw.EdgeInsets.only(left: 10, top: 5, bottom: 5),
                      margin: const pw.EdgeInsets.only(left: 5),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: await widgetChildren(e, Style()),
                      ),
                    ),
                  ])
            ]);
          case "h1": // REF #3
            return Chunk(
                widget: await widgetChildren(
                    e, Style(weight: pw.FontWeight.bold, height: 24)));
          case "h2":
            return Chunk(
                widget: await widgetChildren(
                    e, Style(weight: pw.FontWeight.bold, height: 22))); // REF #1
          case "h3":
            return Chunk(
                widget: await widgetChildren(
                    e, Style(weight: pw.FontWeight.bold, height: 20)));
          case "h4":
            return Chunk(
                widget: await widgetChildren(
                    e, Style(weight: pw.FontWeight.bold, height: 18)));
          case "h5":
            return Chunk(
                widget: await widgetChildren(
                    e, Style(weight: pw.FontWeight.bold, height: 16)));
          case "h6":
            return Chunk(
                widget: await widgetChildren(
                    e, Style(weight: pw.FontWeight.bold, height: 14)));
          case "pre":
            return Chunk(widget: [
              pw.Container(
                  child: pw.Row(
                      children: await widgetChildren(
                        e, Style(font: pw.Font.courier()))),
                  padding: const pw.EdgeInsets.all(5),
                  decoration: const pw.BoxDecoration(
                      borderRadius: pw.BorderRadius.all(pw.Radius.circular(3)),
                      color: PdfColors.grey200))
            ]);
          case "body":
            return Chunk(widget: await widgetChildren(e, Style()));
          //Create a table with the rows stored in rowChildren
          case "table":
            var ch = <pw.TableRow>[];
            //var cellfill = PdfColors.white; // NBT
            //var border = pw.Border.all(width: 1, color: PdfColors.white); // NBT
            Future<void> addRows(Node e, Style s) async {
              for (var r in e.nodes) {
                var cl = <pw.Widget>[];
                for (var c in r.nodes) {
                  if (c.nodeType == Node.TEXT_NODE){continue;} // NBT
                  var ws = await widgetChildren(c, Style());
                  //var align = pw.CrossAxisAlignment.start;
                  var align = pw.CrossAxisAlignment.center; // NBT
                  if (c.attributes["style"] != null) {
                    if (c.attributes["style"] == "text-align: right;") {
                      align = pw.CrossAxisAlignment.end;
                    } else if (c.attributes["style"] == "text-align: center;") {
                      align = pw.CrossAxisAlignment.center;
                    } else if (c.attributes["style"] == "text-align: left;") {
                      align = pw.CrossAxisAlignment.start;
                    }
                  }
                  c as Element;
                  if (c.localName == "th") {
                    //cellfill = PdfColors.grey300; // NBT
                    //cellfill = const PdfColor(1.0, 0.0, 0.0,0.0); // NBT
                    //border = const pw.Border(
                      //  bottom: pw.BorderSide(width: 2),
                        //top: pw.BorderSide(color: PdfColors.white));
                    ws = await widgetChildren(
                        c,
                        Style(
                          weight: pw.FontWeight.bold,
                        ));
                  } else {
                    //cellfill = PdfColors.white; // NBT
                    //cellfill = const PdfColor(1.0,0.0,0.0,0.0); // NBT
                    //border = pw.Border.all(width: 0, color: PdfColors.white);
                  }
                  //cl.add(pw.Column(children: ws, crossAxisAlignment: align)); // NBT
                  cl.add(pw.Expanded(child: pw.Padding(padding: const pw.EdgeInsets.all(15.0),child:pw.Expanded(child: pw.Column(children: ws, crossAxisAlignment: align, mainAxisAlignment: pw.MainAxisAlignment.center))))); // NBT // REF #2
                }
                ch.add(pw.TableRow(
                    children: cl,
                   // decoration: pw.BoxDecoration(border: pw.Border.all(width: 3.0, color: p.PdfColors.blue)) // NBT
                    decoration:
                        //pw.BoxDecoration(color: cellfill, border: border) // NBT
                        pw.BoxDecoration(border: pw.Border.all(width: 1.0, color: p.PdfColors.white), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(1.0))) // NBT
                        ));
              }
            }
            List<Node> toBeRemoved = []; // NBT
            e.nodes.forEach((element){ // 
              if (element.toString().length < 4){ //
                toBeRemoved.add(element); //
              } // 
            }); //
            toBeRemoved.forEach((element){ //
              e.nodes.remove(element); //
            }); // NOTE: there is a bug that causes an empty "new line" Node to be in the list, causing an error, this workaround is to detect and remove these empty nodes
            await addRows(e.nodes[0], Style(weight: pw.FontWeight.bold)); // NBT
            await addRows(e.nodes[1], Style(weight: pw.FontWeight.bold, color: PdfColors.white, boxDecoration: pw.BoxDecoration(border: pw.Border.all(width: 3.0), color: p.PdfColors.blue))); // NBT
            return Chunk(widget: [pw.Table(children: ch)]);
          case "img": // MD2PDF # 1
            //var imageBody = await getImage(e.attributes["src"]); // NBT
            var imageBody = await getImageNBT(e.attributes["src"]); // NBT

            var imageRender = pw.MemoryImage(imageBody);
            return Chunk(widget: [pw.Image(imageRender)]);
          case "p":
            return Chunk(widget: await widgetChildren(e, Style()));
          default:
           // print("${e.localName} is unknown");
            return Chunk(widget: await widgetChildren(e, Style()));
        }
      case Node.ENTITY_NODE:
      case Node.ENTITY_REFERENCE_NODE:
      case Node.NOTATION_NODE:
      case Node.PROCESSING_INSTRUCTION_NODE:
      case Node.ATTRIBUTE_NODE:
      case Node.CDATA_SECTION_NODE:
      case Node.COMMENT_NODE:
      case Node.DOCUMENT_FRAGMENT_NODE:
      case Node.DOCUMENT_NODE:
      case Node.DOCUMENT_TYPE_NODE:
        //print("${e.nodeType} is unknown node type");
    }
    return Chunk();
  }
}

//mdtopdf(String path, String out) async {
mdtopdf(String md2, String exportPath, bool htmlOrPdf, MarkdownStyleSheet style, {Map<String,dynamic> metadata = const {"title": null, "author" : null, "subject" : null}}) async {
  //md2 = md2.replaceAll('\n', '');
  //md2 = md2.replaceAll('\n\n', '\n');
  if (md2.length > 1){
  String s = "";
  md2.split('\n').forEach((line){
    if (line.length > 1){
      s+= line;
      s+= '\n';
    }
  });
  md2 = s;
  }
  var htmlx = md.markdownToHtml(md2,
      inlineSyntaxes: [md.InlineHtmlSyntax()],
      blockSyntaxes: [
        const md.TableSyntax(),
        const md.FencedCodeBlockSyntax(),
        const md.HeaderWithIdSyntax(),
        const md.SetextHeaderWithIdSyntax(),
      ],
      extensionSet: md.ExtensionSet.gitHubWeb);
      if (htmlOrPdf){
  //File("$exportPath.html").writeAsString(htmlx);
  File(exportPath).writeAsString(htmlx);
  return;
      }
  var document = parse(htmlx);
  if (document.body == null) {
    return;
  }
  Chunk ch = await Styler().format(document.body!);  
  var doc = pw.Document(
    compress: true,
    version: p.PdfVersion.pdf_1_5,
    title: metadata["title"],
    author: metadata["author"],
    subject: metadata["subject"],
    creator: "M-Flow 0.1v"
  );
  Color pageBackgroundColor = Color(HexColor(getTheme()["pageBackgroundColor"]).value);
  doc.addPage(pw.MultiPage(
    pageTheme: pw.PageTheme(
    theme: mStyleToThemeData(style),
    buildBackground: (context){
      return pw.Expanded(child: pw.Rectangle(fillColor: p.PdfColor(pageBackgroundColor.red/255.0,pageBackgroundColor.green/255.0,pageBackgroundColor.blue/255.0)));
    }),

    //buildBackground: (context){
      //context.canvas.setFillColor(const p.PdfColor(0.0, 0.0, 1.0));
      //return pw.Rectangle(fillColor: const p.PdfColor(0.0, 1.0, 1.0), strokeColor: const p.PdfColor(0.0, 0.0, 1.0), strokeWidth: 50);
    //}),
   // pageFormat: p.PdfPageFormat.a4,
    build: (context) => ch.widget ?? [])); // REF #MD2PDF
  if (!htmlOrPdf){
  File(exportPath).writeAsBytes(await doc.save());
  }
}

Future<List<dynamic>> generatePdfImageFromMD(String md2,MarkdownStyleSheet style ,{p.PdfPageFormat format = p.PdfPageFormat.a4, pageIndex=0, String? tempTheme, double dpiMultiplicator = 1.0, FilterQuality fq = FilterQuality.low, bool multi = false}) async {
  if (md2 == ""){
    return [null,0]; // TODO: Should be removed
  }
//print(md2);
//print("t");
if (md2.length > 1){
  String s = "";
  md2.split('\n').forEach((line){
    if (line.length > 1){
      s += line;//.replaceRange(line.length-1, line.length, "");
      s += "\n";
      //s += "\n\n";
    //  print(line.replaceRange(line.length-1, line.length, ""));
    }
  });

  //print('\n'.length);
  //md2 = md2.replaceAll('\n\n\n\n', '\n\n');
  //md2 = md2.replaceAll('\n\n', '\n'); // THis fixes a bug
  md2 = s;
  //print(md2);
}

//print(md2);
 // print(s);
 // print(md2);
  //print(md2.contains('\n\n'));
 /* var listS = md2.split('\n');
  var nmd2 = "";
  listS.forEach((line){
    if (line.startsWith('w\$')){
      nmd2 += line.replaceFirst('w\$', '');
      nmd2 += 'w\$';
      nmd2 += '\n';
    } else {
      nmd2 +=line;
      nmd2 += '\n';
    }
  });
  */
  //md2.replaceAll('w\$', '');
  //var htmlx = md.markdownToHtml(nmd2, inlineSyntaxes: [md.InlineHtmlSyntax()],
  var htmlx = md.markdownToHtml(md2, inlineSyntaxes: [md.InlineHtmlSyntax()], // COPY PASTED
  blockSyntaxes: [const md.TableSyntax(),
  const md.FencedCodeBlockSyntax(),
  const md.HeaderWithIdSyntax(),
  const md.SetextHeaderWithIdSyntax()],
  extensionSet: md.ExtensionSet.gitHubWeb);

  var document = parse(htmlx);
  Chunk ch = await Styler().format(document.body!);
  //var controllerS = ScreenshotController();
  //var math = Screenshot(child: Math.tex(md2.replaceAll(r'$$', ''), textStyle: TextStyle(fontSize: 13.0, color: Color.fromRGBO(255, 255, 255, 255)),), controller: controllerS,);
  //var bytes = await controllerS.capture();
  //var bytes = await controllerS.captureFromWidget(Math.tex(md2.replaceAll(r'$$', ''), textStyle: TextStyle(fontSize: 20.0, color: Color.fromARGB(255, 255, 255, 255)))); // [TRANSPARENCY] I looked back into ScreenShot Documentation to find this function | NBT # 1
  //controllerS.captureAndSave("test");
  //print(bytes);
  //var b = await bytes!.toByteData();
 // File("test.png").writeAsBytesSync(bytes);
  //ch.widget!.add(
    //pw.Image(pw.MemoryImage(bytes!))//, height: bytes.height.toDouble(), width: bytes.width.toDouble()) // [TRANSPARENCY] Check 'MD2PDF # 1' Above to see where I got this method from
    //);
  var doc = pw.Document(
    compress: true,
    version: p.PdfVersion.pdf_1_5,);
    Color pageBackgroundColor;
    if (tempTheme == null){
    pageBackgroundColor = Color(HexColor(getTheme()["pageBackgroundColor"]).value);
    } else {
    pageBackgroundColor = Color(HexColor(loadThemeFileReturn(tempTheme)["pageBackgroundColor"]).value);
    }
 // if (multi){
  doc.addPage(pw.MultiPage(
  maxPages: multi ? 200 : 1, //200,
  pageTheme: pw.PageTheme(
    buildBackground: (context){
      return pw.Expanded(child: pw.Rectangle(fillColor: p.PdfColor(pageBackgroundColor.red/255.0,pageBackgroundColor.green/255.0,pageBackgroundColor.blue/255.0)));
    },
//    buildBackground: (context){
  //    return pw.OverflowBox(minWidth: 500,child: pw.Rectangle(fillColor: p.PdfColor.fromHex("#000000FF"))); // [TRANSPARENCY] [IMAD LAGGOUNE]: I learned how to use fromHex from its description
   // },
    theme: mStyleToThemeData(style)),
   build: (context) => ch.widget ?? []));
 /* } else {
  doc.addPage(pw.Page(
    pageTheme: pw.PageTheme(buildBackground: (context){
      return pw.Expanded(child: pw.Rectangle(fillColor: p.PdfColor(pageBackgroundColor.red/255.0, pageBackgroundColor.green/255.0, pageBackgroundColor.blue/255.0)));
    },
    theme: mStyleToThemeData(style)),
    build: (context) => ch.widget!.first));
  }*/


  Uint8List t = await doc.save();
  Stream<PdfRaster> r = Printing.raster(t, dpi: PdfPageFormat.inch*dpiMultiplicator); // [TRANSPARENCY] [IMAD LAGGOUNE]: I learned this from the source code of dart_pdf dependency
                                                                      // PdfPageFormat.inch is 72.0, I learned it from page_format.dart form pdf dependency
  PdfRaster j = await r.elementAt(pageIndex);
  Uint8List k = await j.toPng();
  List<dynamic> imageAndSize = [w.Image.memory(k, width: j.width.toDouble(), height: j.height.toDouble(), fit: BoxFit.fitWidth, filterQuality: fq,),doc.document.pdfPageList.pages.length];
  return imageAndSize;
}

pw.ThemeData? mStyleToThemeData(MarkdownStyleSheet style){
  return pw.ThemeData(
    header0: textStylePDFtoPaint(style.h1),
    header1: textStylePDFtoPaint(style.h2),
    header2: textStylePDFtoPaint(style.h3),
    header3: textStylePDFtoPaint(style.h4),
    header4: textStylePDFtoPaint(style.h5),
    header5: textStylePDFtoPaint(style.h6),
    defaultTextStyle: textStylePDFtoPaint(style.p),
    paragraphStyle: textStylePDFtoPaint(style.p),
    bulletStyle: textStylePDFtoPaint(style.p),
    //iconTheme: IconThemeData(color: PdfColor(1.0, 1.0, 1.0))
  );
}

pw.TextStyle textStylePDFtoPaint(TextStyle? tStyle){
  if (tStyle == null){
    return const pw.TextStyle();
  }
  pw.FontWeight fontWeight = pw.FontWeight.normal;
  if (tStyle.fontWeight == FontWeight.bold){
    fontWeight = pw.FontWeight.bold;
  }
  pw.TextStyle l = pw.TextStyle(
    fontWeight: fontWeight,
    fontSize: tStyle.fontSize,
    //color: p.PdfColor(tStyle.color!.red.toDouble()/255.0,tStyle.color!.green.toDouble()/255.0, tStyle.color!.blue.toDouble()/255.0,tStyle.color!.alpha.toDouble()/255.0),
    color: ColorToPdfColor(tStyle.color),
    decorationColor: ColorToPdfColor(tStyle.decorationColor)
    );
  return l;
}




p.PdfColor? ColorToPdfColor(Color? color){
  if (color == null){
    return null;
  }
  return p.PdfColor(color.red/255.0, color.green/255.0, color.blue/255.0);
}









  // NBT
  // NOTE: this function was copyed from flutter_markdown dependency build.dart file, original code by Madhur Pandey | Modified by Imad Laggoune and Madhur Pandey

/*
  // CUSTOM WIDGET TO APPLY THE SUB & SUPERSCRIPT FEATURES....

  // This method builds a RichText widget with support for custom formatting.
  // It interprets specific charactars (`~` for subscript and `^` for superscript)
  // within the input text and applies the corresponding formatting.
//pw.RichText 
buildTextWithFormattingPDF(String text, pw.TextStyle style) {
    //var alignment = pw.TextAlign.start;
    var aIndex = 0;
    if (text.endsWith("r\$")){
      text = text.replaceRange(text.length-2, text.length, '');
      aIndex = 1;
    } else if (text.endsWith("w\$")){
      text = text.replaceRange(text.length-2, text.length, '');
      aIndex = 2;
    }
    
    // List to hold all the formatted spans (text segments with specific styles)
    final List<pw.InlineSpan> spans = <pw.InlineSpan>[];
    
    // Start iterating over the characters in the input text
    int i = 0;
    while (i < text.length) {
      // COPY PASTED FROM build.dart, Code by Madhur
    if (text[i] == '\\') {
      // Check if the next character is part of a known escape sequence
      if (i + 1 < text.length && (text[i + 1] == '-' || text[i + 1] == '~' || text[i + 1] == '^')) {
        // If yes, treat the next character as a literal
        spans.add(pw.TextSpan(text: text[i + 1], style: style));
        i += 2; // Skip past the escape sequence
      } else {
        // If the backslash is not followed by a known character, treat it as a literal
        spans.add(pw.TextSpan(text: '\\', style: style));
        i += 1; // Move to the next character
      }
    } 

      // END COPY PAST


      // COPY PASTED FROM build.dart, Code by Madhur
      // Check if the current segment is underlined (enclosed in '-')
      if (text.startsWith('-', i) && (i==0 || text[i-1 == -1 ? 0 : i-1] != '\\')) {
        int j = i + 2;

        // Find the closing '-' to determine the underlined text
        while (j < text.length && !text.startsWith('-', j)) {
          j++;
        }

        if (j < text.length) {
          final String underlineText = text.substring(i + 1, j);

          spans.add(pw.TextSpan(
            text: underlineText,
            style: style.copyWith(decoration: pw.TextDecoration.underline),
          ));
          i = j + 1; // Move past the closing '-'
        } else {
          spans.add(pw.TextSpan(text: '-', style: style));
          i += 1;
        }
      }
      // END COPY PAST

      // Check if the current character is a subscript marker '~'
      if (text.startsWith('~', i)) {
        int j = i + 1;

        // Find the closing '~' to determine the subscript text
        while (j < text.length && text[j] != '~') {
          j++;
        }

        // If a closing '~' is found, apply the subscript formatting
        if (j < text.length) {
          final String subscriptText = text.substring(i + 1, j);

          // Create a WidgetSpan for subscript with a vertical offset
          spans.add(
            pw.WidgetSpan(
              child: pw.Transform.translate(
                offset: const p.PdfPoint(0, -3.0*3.0),//styleSheet.textScaler != null ? -styleSheet.textScaler!.scale(3.0*2.0) : -3.0), // adjust vertical offset for subscript
                child: pw.Text(
                  subscriptText,
                  //textScaler: styleSheet.textScaler.,
                //  textScaleFactor: styleSheet.textScaler!.textScaleFactor,
                  style: style.copyWith(
                    fontSize: style.fontSize! * 0.8, // Slightly smaller font size
                    fontWeight: pw.FontWeight.bold, // Make subscript bold
                  ),
                ),
              ),
            ),
          );
          i = j + 1; // Move the index to the character after the closing '~'
        } else {
          // If no closing '~' is found, treat it as a regular character
          spans.add(pw.TextSpan(text: '~', style: style));
          i++;
        }
       // Check if the current character is a superscript marker '^'
      } else if (text.startsWith('^', i)) {
        int j = i + 1;

        // Find the closing '^' to determine the superscript text
      //  while (j < text.length && text[j] != '^') {
        //  j++;
        //}

        // If a closing '^' is found, apply the superscript formatting
        var result = findClosing(text, '^', j);
        if (result != -1) {
          j = result;
          final String superscriptText = text.substring(i + 1, j);

          // Create a WidgetSpan for superscript with a vertical offset
          spans.add(
            pw.WidgetSpan(
              child: pw.Transform.translate(
                //offset: Offset(0, styleSheet.textScaler != null ? -styleSheet.textScaler!.scale(3.0*2.0) : -3.0), // adjust vertical offset for superscript
                offset: const p.PdfPoint(0, 3.0*2.0),//styleSheet.textScaler != null ? -styleSheet.textScaler!.scale(3.0*2.0) : -3.0),
                child: pw.Text(
                  superscriptText,
                  //textScaler: styleSheet.textScaler,
                //  textScaleFactor: styleSheet.textScaler!.textScaleFactor,
                  style: style.copyWith(
                    fontSize: style.fontSize! * 0.7, // Even smaller font size
                    fontWeight: pw.FontWeight.bold, // Make superscript bold
                  ),
                ),
              ),
            ),
          );
          i = j + 1; // Move the index to the character after the closing '^'
        } else {
          // If no closing '^' is found, treat it as a regular character
          spans.add(pw.TextSpan(text: '^', style: style));
          i++;
        }
        // If the current character is neither '~' nor '^', it's regular text
   /*   } else if(text.startsWith('w\$', i)){
        print(text.substring(i,i+2));
        text = text.replaceRange(i, i+2, '');
        i++;
        print(text);
        alignment = pw.TextAlign.center;
        print("aligned");
      //  var result = findClosing(text, 'w\$', i);
      //  if (result != -1){
        //spans.add(pw.TextSpan(text: text.substring(i, result)));
        //}*/
      } else {
        int j = i;
        // Collect all consecutive regular text characters
        while (j < text.length && text[j] != '~' && text[j] != '^' && text[j] != '-' && text[j] != '\\'){// && text[j] != 'w\$') {
          j++;
        }

        // Add the regular text to the spans list without any special formatting
        spans.add(pw.TextSpan(text: text.substring(i, j)));//, style: style.copyWith(fontSize: styleSheet.textScaler!.scale(style.fontSize ?? 16.0)))); // TODO: 16.0 is a const
        i = j; // Move the index to the next character to be processed
      }
    }
    // Return a RichText widget that displays all the spans with the applied formatting

    if (aIndex == 1){
    //return pw.RichText(text: pw.TextSpan(children: spans), textAlign: pw.TextAlign.end);
    return pw.Align(alignment: pw.Alignment.centerRight, child: pw.RichText(text: pw.TextSpan(children: spans), textAlign: pw.TextAlign.end));
    } else if (aIndex == 2){
      return pw.Center(child: pw.RichText(text: pw.TextSpan(children: spans), textAlign: pw.TextAlign.center));
    } else {
      return pw.RichText(text: pw.TextSpan(children: spans));
    }
  }
*/

  int findClosing(String text, String symbol, int start){
        while (start < text.length && text[start] != symbol) {
          start++;
        }
        if (start < text.length){
          return start;
        } else {
          return -1;
        }
  }

  //int getPageCount(){
    //pw.MultiPage().
    
  //}

Future<int> getPageCount(String md2) async { // [T] dart_pdf

// COPY PASTED AND CLEANED
  if (md2 == ""){
    return 0;
  }
if (md2.length > 1){
  String s = "";
  md2.split('\n').forEach((line){
    if (line.length > 1){
      s += line;
      s += "\n";
      //s += "\n";
    }
  });
  md2 = s;
}
  var htmlx = md.markdownToHtml(md2, inlineSyntaxes: [md.InlineHtmlSyntax()], // COPY PASTED

  blockSyntaxes: [const md.TableSyntax(),
  const md.FencedCodeBlockSyntax(),
  const md.HeaderWithIdSyntax(),
  const md.SetextHeaderWithIdSyntax()],
  extensionSet: md.ExtensionSet.gitHubWeb);

  var document = parse(htmlx);
  Chunk ch = await Styler().format(document.body!);
// END OF COPY PAST
    pw.Document doc = pw.Document();
    doc.addPage(pw.MultiPage(build: (context) => ch.widget ?? [])); // [T] REF #MD2PDF  
    return doc.document.pdfPageList.pages.length;
  }
  // NBT Ends