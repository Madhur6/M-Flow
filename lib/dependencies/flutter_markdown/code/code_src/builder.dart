// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// THIS FILE WAS MODIFIED BY NATIVE BITS TEAM

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
//import 'package:flutter_math_fork/flutter_math.dart'; // NBT
import 'package:flutter_math_fork/flutter_math.dart'; // NBT
import 'package:markdown/markdown.dart' as md; // NBT
import 'package:m_flow/functions/ddf/flutter_ddf.dart'; // NBT
//import 'package:m_flow/dependencies/markdown/code/markdown.dart' as md; // NBT HISTORY

import '_functions_io.dart' if (dart.library.js_interop) '_functions_web.dart';
import 'style_sheet.dart';
import 'widget.dart';

final List<String> _kBlockTags = <String>[
  'p',
  'h1',
  'h2',
  'h3',
  'h4',
  'h5',
  'h6',
  'li',
  'blockquote',
  'pre',
  'ol',
  'ul',
  'hr',
  'table',
  'thead',
  'tbody',
  'tr',
  'section',
];

const List<String> _kListTags = <String>['ul', 'ol'];

bool _isBlockTag(String? tag) => _kBlockTags.contains(tag);

bool _isListTag(String tag) => _kListTags.contains(tag);

class _BlockElement {
  _BlockElement(this.tag);

  final String? tag;
  final List<Widget> children = <Widget>[];

  int nextListIndex = 0;
}

class _TableElement {
  final List<TableRow> rows = <TableRow>[];
}

/// A collection of widgets that should be placed adjacent to (inline with)
/// other inline elements in the same parent block.
///
/// Inline elements can be textual (a/em/strong) represented by [Text.rich]
/// widgets or images (img) represented by [Image.network] widgets.
///
/// Inline elements can be nested within other inline elements, inheriting their
/// parent's style along with the style of the block they are in.
///
/// When laying out inline widgets, first, any adjacent Text.rich widgets are
/// merged, then, all inline widgets are enclosed in a parent [Wrap] widget.
class _InlineElement {
  _InlineElement(this.tag, {this.style});

  final String? tag;

  /// Created by merging the style defined for this element's [\\tag] in the
  /// delegate's [\\MarkdownStyleSheet] with the style of its parent.
  final TextStyle? style;

  final List<Widget> children = <Widget>[];
  

  // ADDED FOR PROVIDING SUPPORT FOR SUBSCRIPT USING TILDE `~`...
  TextStyle applySubscriptStyle(TextStyle baseStyle) {
    return baseStyle.copyWith(
      fontFeatures: <FontFeature>[
        FontFeature.enable('subs'), // Subscript font feature
      ],
    );
  }
  // ADDED FOR PROVIDING SUPPORT FOR SUBSCRIPT USING TILDE `~`...

}

/// A delegate used by [MarkdownBuilder] to control the widgets it creates.
abstract class MarkdownBuilderDelegate {
  /// Returns the [BuildContext] of the [MarkdownWidget].
  ///
  /// The context will be passed down to the
  /// [MarkdownElementBuilder.visitElementBefore] method and allows elements to
  /// get information from the context.
  BuildContext get context;

  /// Returns a gesture recognizer to use for an `a` element with the given
  /// text, `href` attribute, and title.
  GestureRecognizer createLink(String text, String? href, String title);

  /// Returns formatted text to use to display the given contents of a `pre`
  /// element.
  ///
  /// The `styleSheet` is the value of [MarkdownBuilder.styleSheet].
  TextSpan formatText(MarkdownStyleSheet styleSheet, String code);
}

/// Builds a [Widget] tree from parsed Markdown.
///
/// See also:
///
///  * [Markdown], which is a widget that parses and displays Markdown.
class MarkdownBuilder implements md.NodeVisitor {
  /// Creates an object that builds a [Widget] tree from parsed Markdown.
  MarkdownBuilder({
    required this.delegate,
    required this.selectable,
    required this.styleSheet,
    required this.imageDirectory,
    required this.imageBuilder,
    required this.checkboxBuilder,
    required this.bulletBuilder,
    required this.builders,
    required this.paddingBuilders,
    required this.listItemCrossAxisAlignment,
    this.fitContent = false,
    this.onSelectionChanged,
    this.onTapText,
    this.softLineBreak = false,
  });

  /// A delegate that controls how link and `pre` elements behave.
  final MarkdownBuilderDelegate delegate;

  /// If true, the text is selectable.
  ///
  /// Defaults to false.
  final bool selectable;

  /// Defines which [TextStyle] objects to use for each type of element.
  final MarkdownStyleSheet styleSheet;

  /// The base directory holding images referenced by Img tags with local or network file paths.
  final String? imageDirectory;

  /// Call when build an image widget.
  final MarkdownImageBuilder? imageBuilder;

  /// Call when build a checkbox widget.
  final MarkdownCheckboxBuilder? checkboxBuilder;

  /// Called when building a custom bullet.
  final MarkdownBulletBuilder? bulletBuilder;

  /// Call when build a custom widget.
  final Map<String, MarkdownElementBuilder> builders;

  /// Call when build a padding for widget.
  final Map<String, MarkdownPaddingBuilder> paddingBuilders;

  /// Whether to allow the widget to fit the child content.
  final bool fitContent;

  /// Controls the cross axis alignment for the bullet and list item content
  /// in lists.
  ///
  /// Defaults to [MarkdownListItemCrossAxisAlignment.baseline], which
  /// does not allow for intrinsic height measurements.
  final MarkdownListItemCrossAxisAlignment listItemCrossAxisAlignment;

  /// Called when the user changes selection when [selectable] is set to true.
  final MarkdownOnSelectionChangedCallback? onSelectionChanged;

  /// Default tap handler used when [selectable] is set to true
  final VoidCallback? onTapText;

  /// The soft line break is used to identify the spaces at the end of aline of
  /// text and the leading spaces in the immediately following the line of text.
  ///
  /// Default these spaces are removed in accordance with the Markdown
  /// specification on soft line breaks when lines of text are joined.
  final bool softLineBreak;

  final List<String> _listIndents = <String>[];
  final List<_BlockElement> _blocks = <_BlockElement>[];
  final List<_TableElement> _tables = <_TableElement>[];
  final List<_InlineElement> _inlines = <_InlineElement>[];
  final List<GestureRecognizer> _linkHandlers = <GestureRecognizer>[];
  String? _currentBlockTag;
  String? _lastVisitedTag;
  bool _isInBlockquote = false;

  /// Returns widgets that display the given Markdown nodes.
  ///
  /// The returned widgets are typically used as children in a [ListView].
  List<Widget> build(List<md.Node> nodes) {
    _listIndents.clear();
    _blocks.clear();
    _tables.clear();
    _inlines.clear();
    _linkHandlers.clear();
    _isInBlockquote = false;

    builders.forEach((String key, MarkdownElementBuilder value) {
      if (value.isBlockElement()) {
        _kBlockTags.add(key);
      }
    });

    _blocks.add(_BlockElement(null));

    for (final md.Node node in nodes) {
      assert(_blocks.length == 1);
      node.accept(this);
    }

    assert(_tables.isEmpty);
    assert(_inlines.isEmpty);
    assert(!_isInBlockquote);
    return _blocks.single.children;
  }

  @override
  bool visitElementBefore(md.Element element) {
    final String tag = element.tag;
    _currentBlockTag ??= tag;
    _lastVisitedTag = tag;

    if (builders.containsKey(tag)) {
      builders[tag]!.visitElementBefore(element);
    }

    if (paddingBuilders.containsKey(tag)) {
      paddingBuilders[tag]!.visitElementBefore(element);
    }

    int? start;
    if (_isBlockTag(tag)) {
if (element.textContent.endsWith("r\$")){_addAnonymousBlockIfNeeded(alignmentIndex: 2);}else //NBT
if (element.textContent.endsWith("w\$")){_addAnonymousBlockIfNeeded(alignmentIndex: 1);} else {_addAnonymousBlockIfNeeded();} // NBT
////////////// NBT Starts, Credits to NBT member Madhur for original Code, Modified to Work here by Imad Laggoune
/*
if (element.textContent.contains(r'\$') || element.textContent.contains(r'$$')) {
        if (element.textContent.startsWith(r'$$') && element.textContent.endsWith(r'$$')) {
          // Block math expression
          element.children!.add(
            Math.tex(element.textContent.replaceAll(r'$$', ''),textStyle: TextStyle(fontSize: 16)) as md.Node);
        } else {
          // Inline math expression
          final parts = element.textContent.split(r'$');
          for (int i = 0; i < parts.length; i++) {
            if (i % 2 == 0) {
              element.children!.add(md.Text(element.textContent));
            } else {
              element.children!.add(Math.tex(parts[i],textStyle: TextStyle(fontSize: 16)) as md.Node);
            }
          }
        }
      }*/
////////////// NBT Ends
      //_addAnonymousBlockIfNeeded(); // ?? NBT ??
      if (_isListTag(tag)) {
        _listIndents.add(tag);
        if (element.attributes['start'] != null) {
          start = int.parse(element.attributes['start']!) - 1;
        }
      } else if (tag == 'blockquote') {
        _isInBlockquote = true;
      } else if (tag == 'table') {
        _tables.add(_TableElement());
      } else if (tag == 'tr') {
        final int length = _tables.single.rows.length;
        BoxDecoration? decoration =
            styleSheet.tableCellsDecoration as BoxDecoration?;
        if (length == 0 || length.isOdd) {
          decoration = null;
        }
        _tables.single.rows.add(TableRow(
          decoration: decoration,
          // TODO(stuartmorgan): This should be fixed, not suppressed; enabling
          // this lint warning exposed that the builder is modifying the
          // children of TableRows, even though they are @immutable.
          // ignore: prefer_const_literals_to_create_immutables
          children: <Widget>[],
        ));
      }
      final _BlockElement bElement = _BlockElement(tag);
      if (start != null) {
        bElement.nextListIndex = start;
      }
      _blocks.add(bElement);
    } else {
      if (tag == 'a') {
        final String? text = extractTextFromElement(element);
        // Don't add empty links
        if (text == null) {
          return false;
        }
        final String? destination = element.attributes['href'];
        final String title = element.attributes['title'] ?? '';

        _linkHandlers.add(
          delegate.createLink(text, destination, title),
        );
      }

      _addParentInlineIfNeeded(_blocks.last.tag);

      // The Markdown parser passes empty table data tags for blank
      // table cells. Insert a text node with an empty string in this
      // case for the table cell to get properly created.
      if (element.tag == 'td' &&
          element.children != null &&
          element.children!.isEmpty) {
        element.children!.add(md.Text(''));
      }

      final TextStyle parentStyle = _inlines.last.style!;
      _inlines.add(_InlineElement(
        tag,
        style: parentStyle.merge(styleSheet.styles[tag]),
      ));
    }

    return true;
  }

  /// Returns the text, if any, from [element] and its descendants.
  String? extractTextFromElement(md.Node element) {
    return element is md.Element && (element.children?.isNotEmpty ?? false)
        ? element.children!
            .map((md.Node e) =>
                e is md.Text ? e.text : extractTextFromElement(e))
            .join()
        : (element is md.Element && (element.attributes.isNotEmpty)
            ? element.attributes['alt']
            : '');
  }

  @override
  void visitText(md.Text text) {
    // Don't allow text directly under the root.
    if (_blocks.last.tag == null) {
      return;
    }

    _addParentInlineIfNeeded(_blocks.last.tag);

    // Define trim text function to remove spaces from text elements in
    // accordance with Markdown specifications.
    String trimText(String text) {
      // The leading spaces pattern is used to identify spaces
      // at the beginning of a line of text.
      final RegExp leadingSpacesPattern = RegExp(r'^ *');

      // The soft line break is used to identify the spaces at the end of a line
      // of text and the leading spaces in the immediately following the line
      // of text. These spaces are removed in accordance with the Markdown
      // specification on soft line breaks when lines of text are joined.
      final RegExp softLineBreakPattern = RegExp(r' ?\n *');

      // Leading spaces following a hard line break are ignored.
      // https://github.github.com/gfm/#example-657
      // Leading spaces in paragraph or list item are ignored
      // https://github.github.com/gfm/#example-192
      // https://github.github.com/gfm/#example-236
      if (const <String>['ul', 'ol', 'li', 'p', 'br']
          .contains(_lastVisitedTag)) {
        text = text.replaceAll(leadingSpacesPattern, '');
      }

      if (softLineBreak) {
        return text;
      }
      return text.replaceAll(softLineBreakPattern, ' ');
    }

    Widget? child;
    if (_blocks.isNotEmpty && builders.containsKey(_blocks.last.tag)) {
      child = builders[_blocks.last.tag!]!
          .visitText(text, styleSheet.styles[_blocks.last.tag!]);
    } else if (_blocks.last.tag == 'pre') {
      final ScrollController preScrollController = ScrollController();
      child = Scrollbar(
        controller: preScrollController,
        child: SingleChildScrollView(
          controller: preScrollController,
          scrollDirection: Axis.horizontal,
          padding: styleSheet.codeblockPadding,
          child: _buildRichText(delegate.formatText(styleSheet, text.text)),
        ),
      );
    } else {
      String o = text.text;
      TextAlign k;
      if (text.text.endsWith("r\$")){
        k = TextAlign.end; //o = text.text.replaceFirst("w\$","");
        if (!(text.text.contains('~') || text.text.contains('-') || text.text.contains('^'))){
        o = text.text.replaceRange(text.text.length-3, text.text.length, '');
        }
      } else if (text.text.endsWith("w\$")) {
        k = TextAlign.center;
        if (!(text.text.contains('~') || text.text.contains('-') || text.text.contains('^'))){
        o = text.text.replaceRange(text.text.length-2, text.text.length, '');
        }
      }
      else {
        k = _textAlignForBlockTag(_currentBlockTag);
      } // NBT

      TextDecoration? d; 
      
    //  if (text.text.endsWith("d\$")){
      //  d = TextDecoration.underline; 
        //o = text.text.replaceFirst("d\$","");
       // o = text.text.replaceRange(text.text.length-2, text.text.length, '');
      //} // NBT
      
      // NBT`````````````````````````````````````````````````````````````````````````````````````````````````````
      // This didn;t worked out, Can remove this``````````````````````````````````````
      // // Handling subscript with tildes (~) and superscript with carets (^)
      // if (o.startsWith("~") && o.endsWith("~")) {
      //   // Subscript
      //   final subscriptText = o.substring(1, o.length - 1);
      //   child = _buildRichText(
      //     TextSpan(
      //       style: _inlines.last.style!.copyWith(
      //         fontFeatures: [FontFeature.subscripts()],
      //       ),
      //       text: _isInBlockquote ? subscriptText : trimText(subscriptText),
      //       recognizer: _linkHandlers.isNotEmpty ? _linkHandlers.last : null,
      //     ),
      //     textAlign: k,
      //   );
      // } else if (o.startsWith("^") && o.endsWith("^")) {
      //   // Superscript
      //   final superscriptText = o.substring(1, o.length - 1);
      //   child = _buildRichText(
      //     TextSpan(
      //       style: _inlines.last.style!.copyWith(
      //         fontFeatures: [FontFeature.superscripts()],
      //       ),
      //       text: _isInBlockquote ? superscriptText : trimText(superscriptText),
      //       recognizer: _linkHandlers.isNotEmpty ? _linkHandlers.last : null,
      //     ),
      //     textAlign: k,
      //   );
      // }
      // ```````````````````````````````````````````````````````````````````````````````````````
      // NBT```````````````````````````````````````````````````````````````````````````````````````````

      // DO NOT REMOVE IT, AS OF NOW....
      //////////// NBT Starts, Credits to NBT member Madhur for original Code, Modified by Imad Laggoune
      // if (text.text.contains(r'\$') || text.text.contains(r'$$')) {
      //   if (text.text.startsWith(r'$$')){// && text.text.endsWith(r'$$')) {
      //   if (text.text.endsWith(r'$$' + "w\$")){
      //     // Block math expression
      //     //_inlines.last.children.add(Math.tex(text.text.replaceAll(r'$$', '').replaceAll(" \\ ", " \\\\ "), textScaleFactor: 1.2));
      //     _inlines.last.children.add(Center(child: Math.tex(text.text.replaceAll(r'$$', '').replaceAll(" \\ ", " \\\\ ").replaceAll('w\$', ''), textScaleFactor: 1.2,)));
      //     print(text.text.replaceAll(r'$$', '').replaceAll(" \\ ", " \\\\ ").replaceAll('w\$', ''));
      //   } else if (text.text.endsWith(r'$$' + "r\$")){
      //     _inlines.last.children.add(Align(alignment: Alignment.centerRight, child: Math.tex(text.text.replaceAll(r'$$', '').replaceAll(" \\ ", " \\\\ ").replaceAll('r\$', ''), textScaleFactor: 1.2)));
      //   } else {
      //     _inlines.last.children.add(Math.tex(text.text.replaceAll(r'$$', '').replaceAll(" \\ ", " \\\\ ")));
      //   }
      //   return;
      //   } else {
      //     if (text.text.endsWith(r'$' + 'w\$')){
      //       var nText = text.text.replaceAll('w\$', '');
      //     // Inline math expression
      //     //final parts = text.text.split(r'$');
      //     final parts = nText.split(r'$');
      //     for (int i = 0; i < parts.length; i++) {
      //       if (i % 2 == 0) {
      //         _inlines.last.children.add(Text(nText));
      //       } else {
      //         _inlines.last.children.add(Center(child:Math.tex(parts[i].replaceAll(" \\ ", " \\\\ "), textScaleFactor: 1.2)));
      //       }
      //     }
      //     } else if (text.text.endsWith(r'$' + 'r\$')) {
      //       var nText = text.text.replaceAll('r\$', '');
      //       final parts = nText.split(r'$');
      //       for (int i = 0; i < parts.length; i++){
      //         if (i % 2 == 0){
      //           _inlines.last.children.add(Text(nText));
      //         } else {
      //           _inlines.last.children.add(Align(alignment: Alignment.centerRight, child: Math.tex(parts[i].replaceAll(" \\ ", " \\\\ "), textScaleFactor: 1.2)));
      //         }
      //       }
      //     }
      //   }
      // }
      ////////////// NBT Ends
      
      TextStyle t = _inlines.last.style!.copyWith(decoration: d);  // Apply the text style decoration
      
      // NBT

      if (o.contains('~') || o.contains('^') || o.contains('-') || o.contains('\$\$') || o.contains('^\$')){
      child = buildTextWithFormatting( //_buildTextWithFormatting(
        _isInBlockquote ? o : trimText(o),  // Pass text with or without blockquote formatting
        t, // Pass the updated text style with decoration
        styleSheet, delegate.context,
      );
      } else{

      //NBT ENDS


      child = _buildRichText(
        TextSpan(
          style: _isInBlockquote
              //? styleSheet.blockquote!.merge(_inlines.last.style)
              //: _inlines.last.style,
              ? styleSheet.blockquote!.merge(t)
              : t,
          //text: _isInBlockquote ? text.text : trimText(text.text),
          text: _isInBlockquote ? o : trimText(o), // NBT
          recognizer: _linkHandlers.isNotEmpty ? _linkHandlers.last : null,
        ),
        //textAlign: _textAlignForBlockTag(_currentBlockTag),
        textAlign: k
      );
      
      // NBT starts here........

      // Apply the _buildTextWithFormatting method to handle subscripts and superscripts
      // Ensure text formatting is correctly applied within blockquote context if necessary
      }
      // NBT ends here.............

    }

    if (child != null) {
      _inlines.last.children.add(child);
    }

    _lastVisitedTag = null;
  }

  @override
  void visitElementAfter(md.Element element) {
    final String tag = element.tag;

    if (_isBlockTag(tag)) {
      if (element.textContent.endsWith("r\$")){_addAnonymousBlockIfNeeded(alignmentIndex: 2);}else //NBT
      if (element.textContent.endsWith("w\$")){_addAnonymousBlockIfNeeded(alignmentIndex: 1);}else {_addAnonymousBlockIfNeeded();} // NBT
      //_addAnonymousBlockIfNeeded();

      final _BlockElement current = _blocks.removeLast();
      Widget child;

      if (current.children.isNotEmpty) {
        child = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: fitContent
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.stretch,
          children: current.children,
        );
      } else {
        child = const SizedBox();
      }

      if (_isListTag(tag)) {
        assert(_listIndents.isNotEmpty);
        _listIndents.removeLast();
      } else if (tag == 'li') {
        if (_listIndents.isNotEmpty) {
          if (element.children!.isEmpty) {
            element.children!.add(md.Text(''));
          }
          Widget bullet;
          final dynamic el = element.children![0];
          if (el is md.Element && el.attributes['type'] == 'checkbox') {
            final bool val = el.attributes.containsKey('checked');
            bullet = _buildCheckbox(val);
          } else {
            bullet = _buildBullet(_listIndents.last);
          }
          child = Row(
            mainAxisSize: fitContent ? MainAxisSize.min : MainAxisSize.max,
            textBaseline: listItemCrossAxisAlignment ==
                    MarkdownListItemCrossAxisAlignment.start
                ? null
                : TextBaseline.alphabetic,
            crossAxisAlignment: listItemCrossAxisAlignment ==
                    MarkdownListItemCrossAxisAlignment.start
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.baseline,
            children: <Widget>[
              SizedBox(
                width: styleSheet.listIndent! +
                    styleSheet.listBulletPadding!.left +
                    styleSheet.listBulletPadding!.right,
                child: bullet,
              ),
              Flexible(
                fit: fitContent ? FlexFit.loose : FlexFit.tight,
                child: child,
              )
            ],
          );
        }
      } else if (tag == 'table') {
        if (styleSheet.tableColumnWidth is FixedColumnWidth) {
          final ScrollController tableScrollController = ScrollController();
          child = Scrollbar(
            controller: tableScrollController,
            child: SingleChildScrollView(
              controller: tableScrollController,
              scrollDirection: Axis.horizontal,
              padding: styleSheet.tablePadding,
              child: _buildTable(),
            ),
          );
        } else {
          child = _buildTable();
        }
      } else if (tag == 'blockquote') {
        _isInBlockquote = false;
        child = DecoratedBox(
          decoration: styleSheet.blockquoteDecoration!,
          child: Padding(
            padding: styleSheet.blockquotePadding!,
            child: child,
          ),
        );
      } else if (tag == 'pre') {
        child = Container(
          clipBehavior: Clip.hardEdge,
          decoration: styleSheet.codeblockDecoration,
          child: child,
        );
      } else if (tag == 'hr') {
        child = Container(decoration: styleSheet.horizontalRuleDecoration);
      }

      _addBlockChild(child);
    } else {
      final _InlineElement current = _inlines.removeLast();
      final _InlineElement parent = _inlines.last;
      EdgeInsets padding = EdgeInsets.zero;

      if (paddingBuilders.containsKey(tag)) {
        padding = paddingBuilders[tag]!.getPadding();
      }

      if (builders.containsKey(tag)) {
        final Widget? child = builders[tag]!.visitElementAfterWithContext(
          delegate.context,
          element,
          styleSheet.styles[tag],
          parent.style,
        );
        if (child != null) {
          if (current.children.isEmpty) {
            current.children.add(child);
          } else {
            current.children[0] = child;
          }
        }
      } else if (tag == 'img') {
        // create an image widget for this image
        current.children.add(_buildPadding(
          padding,
          _buildImage(
            element.attributes['src']!,
            element.attributes['title'],
            element.attributes['alt'],
          ),
        ));
      } else if (tag == 'br') {
        current.children.add(_buildRichText(const TextSpan(text: '\n')));
      } else if (tag == 'th' || tag == 'td') {
        TextAlign? align;
        final String? alignAttribute = element.attributes['align'];
        if (alignAttribute == null) {
          align = tag == 'th' ? styleSheet.tableHeadAlign : TextAlign.left;
        } else {
          switch (alignAttribute) {
            case 'left':
              align = TextAlign.left;
            case 'center':
              align = TextAlign.center;
            case 'right':
              align = TextAlign.right;
          }
        }
        final Widget child = _buildTableCell(
          _mergeInlineChildren(current.children, align),
          textAlign: align,
        );
        _tables.single.rows.last.children.add(child);
      } else if (tag == 'a') {
        _linkHandlers.removeLast();
      } else if (tag == 'sup') {
        final Widget c = current.children.last;
        TextSpan? textSpan;
        if (c is Text && c.textSpan is TextSpan) {
          textSpan = c.textSpan! as TextSpan;
        } else if (c is SelectableText && c.textSpan is TextSpan) {
          textSpan = c.textSpan;
        }
        if (textSpan != null) {
          final Widget richText = _buildRichText(
            TextSpan(
              recognizer: textSpan.recognizer,
              text: element.textContent,
              style: textSpan.style?.copyWith(
                fontFeatures: <FontFeature>[
                  const FontFeature.enable('sups'),
                  if (styleSheet.superscriptFontFeatureTag != null)
                    FontFeature.enable(styleSheet.superscriptFontFeatureTag!),
                ],
              ),
            ),
          );
          current.children.removeLast();
          current.children.add(richText);
        }
      }

      if (current.children.isNotEmpty) {
        parent.children.addAll(current.children);
      }
    }
    if (_currentBlockTag == tag) {
      _currentBlockTag = null;
    }
    _lastVisitedTag = tag;
  }

  Table _buildTable() {
    return Table(
      defaultColumnWidth: styleSheet.tableColumnWidth!,
      defaultVerticalAlignment: styleSheet.tableVerticalAlignment,
      border: styleSheet.tableBorder,
      children: _tables.removeLast().rows,
    );
  }

  Widget _buildImage(String src, String? title, String? alt) {
    final List<String> parts = src.split('#');
    if (parts.isEmpty) {
      return const SizedBox();
    }

    final String path = parts.first;
    double? width;
    double? height;
    if (parts.length == 2) {
      final List<String> dimensions = parts.last.split('x');
      if (dimensions.length == 2) {
        width = double.tryParse(dimensions[0]);
        height = double.tryParse(dimensions[1]);
      }
    }

    final Uri uri = Uri.parse(path);
    Widget child;
    if (imageBuilder != null) {
      child = imageBuilder!(uri, title, alt);
    } else {
      child = kDefaultImageBuilder(uri, imageDirectory, width, height);
    }

    if (_linkHandlers.isNotEmpty) {
      final TapGestureRecognizer recognizer =
          _linkHandlers.last as TapGestureRecognizer;
      return GestureDetector(onTap: recognizer.onTap, child: child);
    } else {
      return child;
    }
  }

  Widget _buildCheckbox(bool checked) {
    if (checkboxBuilder != null) {
      return checkboxBuilder!(checked);
    }
    return Padding(
      padding: styleSheet.listBulletPadding!,
      child: Icon(
        checked ? Icons.check_box : Icons.check_box_outline_blank,
        size: styleSheet.checkbox!.fontSize,
        color: styleSheet.checkbox!.color,
      ),
    );
  }

  Widget _buildBullet(String listTag) {
    final int index = _blocks.last.nextListIndex;
    final bool isUnordered = listTag == 'ul';

    if (bulletBuilder != null) {
      return Padding(
        padding: styleSheet.listBulletPadding!,
        child: bulletBuilder!(
          MarkdownBulletParameters(
            index: index,
            style: isUnordered
                ? BulletStyle.unorderedList
                : BulletStyle.orderedList,
            nestLevel: _listIndents.length - 1,
          ),
        ),
      );
    }

    if (isUnordered) {
      return Padding(
        padding: styleSheet.listBulletPadding!,
        child: Text(
          '•',
          textAlign: TextAlign.center,
          style: styleSheet.listBullet,
        ),
      );
    }

    return Padding(
      padding: styleSheet.listBulletPadding!,
      child: Text(
        '${index + 1}.',
        textAlign: TextAlign.right,
        style: styleSheet.listBullet,
      ),
    );
  }

  Widget _buildTableCell(List<Widget?> children, {TextAlign? textAlign}) {
    return TableCell(
      child: Padding(
        padding: styleSheet.tableCellsPadding!,
        child: DefaultTextStyle(
          style: styleSheet.tableBody!,
          textAlign: textAlign,
          child: Wrap(children: children as List<Widget>),
        ),
      ),
    );
  }

  Widget _buildPadding(EdgeInsets padding, Widget child) {
    if (padding == EdgeInsets.zero) {
      return child;
    }

    return Padding(padding: padding, child: child);
  }

  void _addParentInlineIfNeeded(String? tag) {
    if (_inlines.isEmpty) {
      _inlines.add(_InlineElement(
        tag,
        style: styleSheet.styles[tag!],
      ));
    }
  }

  void _addBlockChild(Widget child) {
    final _BlockElement parent = _blocks.last;
    if (parent.children.isNotEmpty) {
      parent.children.add(SizedBox(height: styleSheet.blockSpacing));
    }
    parent.children.add(child);
    parent.nextListIndex += 1;
  }

  void _addAnonymousBlockIfNeeded({int alignmentIndex = 0}) { // NBT MODIFIED
    if (_inlines.isEmpty) {
      return;
    }

    WrapAlignment blockAlignment = WrapAlignment.start;
    TextAlign textAlign = TextAlign.start;
    EdgeInsets textPadding = EdgeInsets.zero;
    if (_isBlockTag(_currentBlockTag)) {
      // NBT STARTS
if (alignmentIndex == 1){
  blockAlignment = WrapAlignment.center;
  textAlign = TextAlign.center;
  }else if (alignmentIndex == 2){
    blockAlignment = WrapAlignment.end;
    textAlign = TextAlign.end;
  }
  else {blockAlignment = _wrapAlignmentForBlockTag(_currentBlockTag); textAlign = _textAlignForBlockTag(_currentBlockTag);} // NBT
// NBT ENDS
      //blockAlignment = _wrapAlignmentForBlockTag(_currentBlockTag);
      //textAlign = _textAlignForBlockTag(_currentBlockTag);
      textPadding = _textPaddingForBlockTag(_currentBlockTag);

      if (paddingBuilders.containsKey(_currentBlockTag)) {
        textPadding = paddingBuilders[_currentBlockTag]!.getPadding();
      }
    }

    final _InlineElement inline = _inlines.single;
    if (inline.children.isNotEmpty) {
      final List<Widget> mergedInlines = _mergeInlineChildren(
        inline.children,
        textAlign,
      );
      final Wrap wrap = Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: blockAlignment,
        children: mergedInlines,
      );

      if (textPadding == EdgeInsets.zero) {
        _addBlockChild(wrap);
      } else {
        final Padding padding = Padding(padding: textPadding, child: wrap);
        _addBlockChild(padding);
      }

      _inlines.clear();
    }
  }

  /// Extracts all spans from an inline element and merges them into a single list
  Iterable<InlineSpan> _getInlineSpans(InlineSpan span) {
    // If the span is not a TextSpan or it has no children, return the span
    if (span is! TextSpan || span.children == null) {
      return <InlineSpan>[span];
    }

    // Merge the style of the parent with the style of the children
    final Iterable<InlineSpan> spans =
        span.children!.map((InlineSpan childSpan) {
      if (childSpan is TextSpan) {
        return TextSpan(
          text: childSpan.text,
          recognizer: childSpan.recognizer,
          semanticsLabel: childSpan.semanticsLabel,
          style: childSpan.style?.merge(span.style),
        );
      } else {
        return childSpan;
      }
    });

    return spans;
  }

  /// Merges adjacent [TextSpan] children
  List<Widget> _mergeInlineChildren(
    List<Widget> children,
    TextAlign? textAlign,
  ) {
    // List of merged text spans and widgets
    final List<Widget> mergedTexts = <Widget>[];
    bool skipNext = false; // NBT
    for (final Widget child in children) {
      if (skipNext){skipNext=false;continue;}
      if (child is Math){skipNext = true;} // NBT
      // If the list is empty, add the current widget to the list
      if (mergedTexts.isEmpty) {
        mergedTexts.add(child);
        continue;
      }

      // Remove last widget from the list to merge it with the current widget
      final Widget last = mergedTexts.removeLast();

      // Extracted spans from the last and the current widget
      List<InlineSpan> spans = <InlineSpan>[];

      // Extract the text spans from the last widget
      if (last is SelectableText) {
        final TextSpan span = last.textSpan!;
        spans.addAll(_getInlineSpans(span));
      } else if (last is Text) {
        if (last.textSpan == null){continue;} // NBT
        final InlineSpan span = last.textSpan!;
        spans.addAll(_getInlineSpans(span));
      } else if (last is RichText) {
        final InlineSpan span = last.text;
        spans.addAll(_getInlineSpans(span));
      } else {
        // If the last widget is not a text widget,
        // add both the last and the current widget to the list
        mergedTexts.addAll(<Widget>[last, child]);
        continue;
      }

      // Extract the text spans from the current widget
      if (child is Text) {
        final InlineSpan span = child.textSpan!;
        spans.addAll(_getInlineSpans(span));
      } else if (child is SelectableText) {
        final TextSpan span = child.textSpan!;
        spans.addAll(_getInlineSpans(span));
      } else if (child is RichText) {
        final InlineSpan span = child.text;
        spans.addAll(_getInlineSpans(span));
      } else {
        // If the current widget is not a text widget,
        // add both the last and the current widget to the list
        mergedTexts.addAll(<Widget>[last, child]);
        continue;
      }

      if (spans.isNotEmpty) {
        // Merge similar text spans
        spans = _mergeSimilarTextSpans(spans);

        // Create a new text widget with the merged text spans
        InlineSpan child;
        if (spans.length == 1) {
          child = spans.first;
        } else {
          child = TextSpan(children: spans);
        }

        // Add the new text widget to the list
        if (selectable) {
          mergedTexts.add(SelectableText.rich(
            TextSpan(children: spans),
            textScaler: styleSheet.textScaler,
            textAlign: textAlign ?? TextAlign.start,
            onTap: onTapText,
          ));
        } else {
          mergedTexts.add(Text.rich(
            child,
            textScaler: styleSheet.textScaler,
            textAlign: textAlign ?? TextAlign.start,
          ));
        }
      } else {
        // If no text spans were found, add the current widget to the list
        mergedTexts.add(child);
      }
    }

    return mergedTexts;
  }

  TextAlign _textAlignForBlockTag(String? blockTag) {
    final WrapAlignment wrapAlignment = _wrapAlignmentForBlockTag(blockTag);
    switch (wrapAlignment) {
      case WrapAlignment.start:
        return TextAlign.start;
      case WrapAlignment.center:
        return TextAlign.center;
      case WrapAlignment.end:
        return TextAlign.end;
      case WrapAlignment.spaceAround:
        return TextAlign.justify;
      case WrapAlignment.spaceBetween:
        return TextAlign.justify;
      case WrapAlignment.spaceEvenly:
        return TextAlign.justify;
    }
  }

  WrapAlignment _wrapAlignmentForBlockTag(String? blockTag) {
    switch (blockTag) {
      case 'p':
        return styleSheet.textAlign;
      case 'h1':
        return styleSheet.h1Align;
      case 'h2':
        return styleSheet.h2Align;
      case 'h3':
        return styleSheet.h3Align;
      case 'h4':
        return styleSheet.h4Align;
      case 'h5':
        return styleSheet.h5Align;
      case 'h6':
        return styleSheet.h6Align;
      case 'ul':
        return styleSheet.unorderedListAlign;
      case 'ol':
        return styleSheet.orderedListAlign;
      case 'blockquote':
        return styleSheet.blockquoteAlign;
      case 'pre':
        return styleSheet.codeblockAlign;
      case 'hr':
        break;
      case 'li':
        break;
    }
    return WrapAlignment.start;
  }

  EdgeInsets _textPaddingForBlockTag(String? blockTag) {
    switch (blockTag) {
      case 'p':
        return styleSheet.pPadding!;
      case 'h1':
        return styleSheet.h1Padding!;
      case 'h2':
        return styleSheet.h2Padding!;
      case 'h3':
        return styleSheet.h3Padding!;
      case 'h4':
        return styleSheet.h4Padding!;
      case 'h5':
        return styleSheet.h5Padding!;
      case 'h6':
        return styleSheet.h6Padding!;
    }
    return EdgeInsets.zero;
  }

  /// Combine text spans with equivalent properties into a single span.
  List<InlineSpan> _mergeSimilarTextSpans(List<InlineSpan> textSpans) {
    if (textSpans.length < 2) {
      return textSpans;
    }

    final List<InlineSpan> mergedSpans = <InlineSpan>[];

    for (int index = 1; index < textSpans.length; index++) {
      final InlineSpan previous =
          mergedSpans.isEmpty ? textSpans.first : mergedSpans.removeLast();
      final InlineSpan nextChild = textSpans[index];

      final bool previousIsTextSpan = previous is TextSpan;
      final bool nextIsTextSpan = nextChild is TextSpan;
      if (!previousIsTextSpan || !nextIsTextSpan) {
        mergedSpans.addAll(<InlineSpan>[previous, nextChild]);
        continue;
      }

      final bool matchStyle = nextChild.recognizer == previous.recognizer &&
          nextChild.semanticsLabel == previous.semanticsLabel &&
          nextChild.style == previous.style;

      if (matchStyle) {
        mergedSpans.add(TextSpan(
          text: previous.toPlainText() + nextChild.toPlainText(),
          recognizer: previous.recognizer,
          semanticsLabel: previous.semanticsLabel,
          style: previous.style,
        ));
      } else {
        mergedSpans.addAll(<InlineSpan>[previous, nextChild]);
      }
    }

    // When the mergered spans compress into a single TextSpan return just that
    // TextSpan, otherwise bundle the set of TextSpans under a single parent.
    return mergedSpans;
  }

  Widget _buildRichText(TextSpan? text, {TextAlign? textAlign, String? key}) {
    //Adding a unique key prevents the problem of using the same link handler for text spans with the same text
    final Key k = key == null ? UniqueKey() : Key(key);
    if (selectable) {
      return SelectableText.rich(
        text!,
        textScaler: styleSheet.textScaler,
        textAlign: textAlign ?? TextAlign.start,
        onSelectionChanged: onSelectionChanged != null
            ? (TextSelection selection, SelectionChangedCause? cause) =>
                onSelectionChanged!(text.text, selection, cause)
            : null,
        onTap: onTapText,
        key: k,
      );
    } else {
      return Text.rich(
        text!,
        textScaler: styleSheet.textScaler,
        textAlign: textAlign ?? TextAlign.start,
        key: k,
      );
    }
  }

  // NBT
  // HELPER METHOD...........................................................
  // MOVED TO flutter_ddf.dart outside dependency folder
  /*double getTextWidth(String text, TextStyle style, BuildContext context) {
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
  }*/
// END NBT


  // NBT
  // CUSTOM WIDGET TO APPLY THE SUB & SUPERSCRIPT FEATURES....

  // This method builds a RichText widget with support for custom formatting.
  // It interprets specific charactars git(`~` for subscript and `^` for superscript)
  // within the input text and applies the corresponding formatting.
  
  /* // MOVED TO flutter_ddf.dart outside dependency folder 
  Widget _buildTextWithFormatting(String text, TextStyle style, MarkdownStyleSheet styleSheet, BuildContext context) {
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
        print(text.length);
        while (j < text.length && text[j] != '~' && text[j] != '^' && !text.startsWith('--', j) && text[j] != '\\' && !text.startsWith('\$\$',j)){//text[j] != '\$') {
          print(j);
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
  }*/
  // NBT Ends




}