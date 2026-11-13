import 'dart:async';
import 'dart:html' as html;

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../data/posting_repository.dart';
import '../utils/posting_period.dart';

class PostingPdfExportService {
  Future<void> download(
    List<PostingPreviewItem> postings, {
    required DateTime periodStartDate,
    required DateTime periodEndDate,
  }) async {
    // The built-in PDF Helvetica fonts do not cover Unicode. Use Noto Sans
    // so accented and other supported characters in student names render.
    final bodyFont = await PdfGoogleFonts.notoSansRegular();
    final boldFont = await PdfGoogleFonts.notoSansBold();

    final document = pw.Document();
    final rows = <List<String>>[
      for (var i = 0; i < postings.length; i++)
        [
          (i + 1).toString(),
          postings[i].student.name,
          postings[i].student.phoneNumber,
          postings[i].student.groupName,
          postings[i].unit.name,
        ],
    ];

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.fromLTRB(24, 28, 24, 28),
        theme: pw.ThemeData.withFont(
          base: bodyFont,
          bold: boldFont,
        ),
        build: (context) => [
          pw.Center(
            child: pw.Text(
              'DIGITAL HEALTH DEPARTMENT',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(font: boldFont, fontSize: 15),
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Center(
            child: pw.Text(
              'POSTING OF SIWES STUDENTS EFFECTIVE FROM ' +
                  PostingPeriod.formatDate(periodStartDate) +
                  ' TO ' +
                  PostingPeriod.formatDate(periodEndDate),
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(font: boldFont, fontSize: 11),
            ),
          ),
          pw.SizedBox(height: 18),
          pw.TableHelper.fromTextArray(
            headers: const ['S/N', 'Name', 'Phone Number', 'Group', 'Posting'],
            data: rows,
            border: pw.TableBorder.all(color: PdfColors.black, width: 0.6),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            headerStyle: pw.TextStyle(font: boldFont, fontSize: 9),
            cellStyle: pw.TextStyle(font: bodyFont, fontSize: 8),
            cellAlignment: pw.Alignment.centerLeft,
            headerAlignment: pw.Alignment.center,
            cellPadding: const pw.EdgeInsets.symmetric(
              horizontal: 6,
              vertical: 5,
            ),
          ),
        ],
      ),
    );

    final bytes = await document.save();
    final blob = html.Blob([bytes], 'application/pdf');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..download = 'AKTH_SIWES_Posting_' +
          PostingPeriod.fileDate(periodStartDate) +
          '_to_' +
          PostingPeriod.fileDate(periodEndDate) +
          '.pdf'
      ..click();
    Timer(const Duration(seconds: 1), () => html.Url.revokeObjectUrl(url));
  }
}
