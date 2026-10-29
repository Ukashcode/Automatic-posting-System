import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

import '../data/posting_repository.dart';

class PostingExcelExportService {
  void download(List<PostingView> postings) {
    final bytes = _workbookBytes(postings);
    final blob = html.Blob([
      bytes,
    ], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..download = 'AKTH_SIWES_Postings.xlsx'
      ..click();
    Timer(const Duration(seconds: 1), () => html.Url.revokeObjectUrl(url));
  }

  Uint8List _workbookBytes(List<PostingView> postings) {
    const headers = [
      'S/N',
      'Student Name',
      'Phone Number',
      'Group',
      'Posting Unit',
    ];
    final rows = <List<String>>[
      headers,
      for (var i = 0; i < postings.length; i++)
        [
          '${i + 1}',
          postings[i].student.name,
          postings[i].student.phoneNumber,
          postings[i].student.groupName,
          postings[i].unit.name,
        ],
    ];

    final sheetRows = <String>[];
    for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
      final cells = <String>[];
      for (
        var columnIndex = 0;
        columnIndex < rows[rowIndex].length;
        columnIndex++
      ) {
        final cellRef = '${_columnName(columnIndex + 1)}${rowIndex + 1}';
        final value = _xmlEscape(rows[rowIndex][columnIndex]);
        cells.add(
          '<c r="$cellRef" t="inlineStr"><is><t xml:space="preserve">$value</t></is></c>',
        );
      }
      sheetRows.add('<row r="${rowIndex + 1}">${cells.join()}</row>');
    }

    final sheetXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>${sheetRows.join()}</sheetData></worksheet>''';
    final files = <String, String>{
      '[Content_Types].xml':
          '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/></Types>''',
      '_rels/.rels': '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>''',
      'xl/workbook.xml':
          '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="Postings" sheetId="1" r:id="rId1"/></sheets></workbook>''',
      'xl/_rels/workbook.xml.rels':
          '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/></Relationships>''',
      'xl/worksheets/sheet1.xml': sheetXml,
    };
    return _zip(files);
  }

  String _columnName(int number) {
    var result = '';
    while (number > 0) {
      number--;
      result = String.fromCharCode(65 + number % 26) + result;
      number ~/= 26;
    }
    return result;
  }

  String _xmlEscape(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');

  Uint8List _zip(Map<String, String> files) {
    final output = BytesBuilder(copy: false);
    final directory = BytesBuilder(copy: false);
    var offset = 0;

    for (final entry in files.entries) {
      final name = utf8.encode(entry.key);
      final data = utf8.encode(entry.value);
      final crc = _crc32(data);
      final localHeader = ByteData(30);
      localHeader.setUint32(0, 0x04034b50, Endian.little);
      localHeader.setUint16(4, 20, Endian.little);
      localHeader.setUint16(6, 0x0800, Endian.little);
      localHeader.setUint16(8, 0, Endian.little);
      localHeader.setUint16(10, 0, Endian.little);
      localHeader.setUint16(12, 0x0021, Endian.little);
      localHeader.setUint32(14, crc, Endian.little);
      localHeader.setUint32(18, data.length, Endian.little);
      localHeader.setUint32(22, data.length, Endian.little);
      localHeader.setUint16(26, name.length, Endian.little);
      localHeader.setUint16(28, 0, Endian.little);
      output.add(localHeader.buffer.asUint8List());
      output.add(name);
      output.add(data);

      final centralHeader = ByteData(46);
      centralHeader.setUint32(0, 0x02014b50, Endian.little);
      centralHeader.setUint16(4, 20, Endian.little);
      centralHeader.setUint16(6, 20, Endian.little);
      centralHeader.setUint16(8, 0x0800, Endian.little);
      centralHeader.setUint16(10, 0, Endian.little);
      centralHeader.setUint16(12, 0, Endian.little);
      centralHeader.setUint16(14, 0x0021, Endian.little);
      centralHeader.setUint32(16, crc, Endian.little);
      centralHeader.setUint32(20, data.length, Endian.little);
      centralHeader.setUint32(24, data.length, Endian.little);
      centralHeader.setUint16(28, name.length, Endian.little);
      centralHeader.setUint16(30, 0, Endian.little);
      centralHeader.setUint16(32, 0, Endian.little);
      centralHeader.setUint16(34, 0, Endian.little);
      centralHeader.setUint16(36, 0, Endian.little);
      centralHeader.setUint32(38, 0, Endian.little);
      centralHeader.setUint32(42, offset, Endian.little);
      directory.add(centralHeader.buffer.asUint8List());
      directory.add(name);
      offset += 30 + name.length + data.length;
    }

    final directoryBytes = directory.takeBytes();
    final endRecord = ByteData(22);
    endRecord.setUint32(0, 0x06054b50, Endian.little);
    endRecord.setUint16(4, 0, Endian.little);
    endRecord.setUint16(6, 0, Endian.little);
    endRecord.setUint16(8, files.length, Endian.little);
    endRecord.setUint16(10, files.length, Endian.little);
    endRecord.setUint32(12, directoryBytes.length, Endian.little);
    endRecord.setUint32(16, offset, Endian.little);
    endRecord.setUint16(20, 0, Endian.little);
    output.add(directoryBytes);
    output.add(endRecord.buffer.asUint8List());
    return output.takeBytes();
  }

  int _crc32(List<int> bytes) {
    var crc = 0xffffffff;
    for (final byte in bytes) {
      crc ^= byte;
      for (var bit = 0; bit < 8; bit++) {
        crc = (crc & 1) == 1 ? (crc >> 1) ^ 0xedb88320 : crc >> 1;
      }
    }
    return (crc ^ 0xffffffff) & 0xffffffff;
  }
}
