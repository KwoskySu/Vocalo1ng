import 'phone_theme.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import '../services/wiki.dart';
import 'wiki_image.dart';
import 'package:html/dom.dart' as dom;

class WikiMosaic extends StatefulWidget {
  const WikiMosaic({super.key, required this.entries, required this.onOpen});
  final List<WikiEntry> entries;
  final ValueChanged<WikiEntry> onOpen;
  @override
  State<WikiMosaic> createState() => _WikiMosaicState();
}

class _WikiMosaicState extends State<WikiMosaic> {
  int seed = Random().nextInt(100000);
  @override
  void didUpdateWidget(WikiMosaic old) {
    super.didUpdateWidget(old);
    if (old.entries != widget.entries) seed = Random().nextInt(100000);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final count = box.maxWidth > 900
          ? 3
          : box.maxWidth >= (isPhoneLayout(context) ? 280 : 520)
          ? 2
          : 1;
      final columns = List.generate(count, (_) => <Widget>[]);
      final heights = List.filled(count, 0.0);
      final random = Random(seed);
      final width = (box.maxWidth - (count - 1) * 14) / count;
      for (final entry in widget.entries) {
        final style = random.nextInt(6),
            height =
                width *
                (isPhoneLayout(context)
                    ? .76 + random.nextDouble() * .16
                    : .65 + random.nextDouble() * .45);
        final col = heights.indexOf(heights.reduce(min));
        heights[col] += height + 95;
        final color = Color.lerp(
          Theme.of(context).colorScheme.primary,
          Colors.white,
          .89 + style * .012,
        )!;
        columns[col].add(
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Material(
              color: color,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(style.isEven ? 24 : 3),
                side: BorderSide(
                  color: style == 3
                      ? Colors.black
                      : Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: .2),
                  width: style == 3 ? 2 : 1,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => widget.onOpen(entry),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: height,
                      width: width,
                      child: entry.image.isEmpty
                          ? const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.menu_book_outlined, size: 54),
                                  SizedBox(height: 10),
                                  Text(
                                    '此条目未提供封面',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            )
                          : Center(
                              child: buildWikiImage(
                                dom.Element.tag('img')
                                  ..attributes['src'] = entry.image
                                  ..attributes['width'] = '${width.round()}'
                                  ..attributes['height'] = '${height.round()}'
                                  ..attributes['alt'] = entry.title,
                              ),
                            ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(style == 4 ? 22 : 15),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: isPhoneLayout(context)
                                  ? 14
                                  : style == 2
                                  ? 23
                                  : 18,
                              fontWeight: FontWeight.w800,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 7),
                          const Text(
                            'VocaWiki · 打开条目',
                            style: TextStyle(fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < count; i++) ...[
            if (i > 0) const SizedBox(width: 14),
            Expanded(child: Column(children: columns[i])),
          ],
        ],
      );
    },
  );
}
