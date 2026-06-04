// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:meshmore_sns_app/docs/markdown_view.dart';

Widget _wrap(String md) => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: MarkdownView(md)),
      ),
    );

void main() {
  testWidgets('renders headings, lists, code and links without throwing',
      (WidgetTester tester) async {
    const String sample = '''
# Title

Intro paragraph with **bold**, _italic_ and `inline code`.

## Section

- first item
- second item with a [link](https://example.com)

1. step one
2. step two

```
a fenced code block
```

> a blockquote

| A | B |
|---|---|
| 1 | 2 |
''';
    await tester.pumpWidget(_wrap(sample));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(MarkdownView), findsOneWidget);
    // The fenced code block renders as a plain Text we can find verbatim.
    expect(find.text('a fenced code block'), findsOneWidget);
    // Lists produce bullet markers.
    expect(find.text('▹'), findsWidgets);
    // The table renders as a Table widget.
    expect(find.byType(Table), findsOneWidget);
  });

  testWidgets('empty input renders nothing and does not throw',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(''));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(MarkdownView), findsOneWidget);
  });
}
