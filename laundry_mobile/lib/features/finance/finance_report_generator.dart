import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'providers/finance_provider.dart';

/// Generates a branded PDF financial report and opens the OS share sheet.
class FinanceReportGenerator {
  /// Builds a PDF report for [stats] belonging to [officeName].
  /// Returns the generated PDF bytes.
  static Future<Uint8List> generatePdfBytes(
    FinanceStats stats,
    String officeName,
  ) async {
    final pdf = pw.Document(
      title: '$officeName — Financial Report',
      author: 'Sparkles Laundry',
    );

    // ── Colour palette matching the app theme ──
    const primary = PdfColor.fromInt(0xFF7C3AED); // AppTheme.primaryColor
    const darkText = PdfColor.fromInt(0xFF1A1A2E);
    const secondaryText = PdfColor.fromInt(0xFF6B7280);
    const surface = PdfColor.fromInt(0xFFF9FAFB);
    const completed = PdfColor.fromInt(0xFF7C3AED);
    const pending = PdfColors.orange;
    const overdue = PdfColors.redAccent;
    const white = PdfColors.white;

    final now = DateTime.now();
    final reportDate =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

    // ── Fonts ──
    final fontBold = await PdfGoogleFonts.interBold();
    final fontRegular = await PdfGoogleFonts.interRegular();
    final fontMedium = await PdfGoogleFonts.interMedium();

    pw.TextStyle h1(PdfColor color) => pw.TextStyle(
          font: fontBold,
          fontSize: 22,
          color: color,
        );
    pw.TextStyle h2() => pw.TextStyle(
          font: fontBold,
          fontSize: 14,
          color: darkText,
        );
    pw.TextStyle body() => pw.TextStyle(
          font: fontRegular,
          fontSize: 10,
          color: darkText,
        );
    pw.TextStyle label() => pw.TextStyle(
          font: fontMedium,
          fontSize: 9,
          color: secondaryText,
        );
    pw.TextStyle mono(PdfColor color) => pw.TextStyle(
          font: fontBold,
          fontSize: 18,
          color: color,
        );

    // ── Helpers ──
    String fmt(double v) =>
        '₦${v.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+\.)'), (m) => '${m[1]},')}';

    pw.Widget kpiCard(String title, String value, PdfColor accent) =>
        pw.Expanded(
          child: pw.Container(
            margin: const pw.EdgeInsets.only(right: 8),
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: surface,
              borderRadius: pw.BorderRadius.circular(8),
              border: pw.Border.all(color: accent, width: 2),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(title, style: label()),
                pw.SizedBox(height: 6),
                pw.Text(value, style: mono(accent)),
              ],
            ),
          ),
        );

    pw.Widget tableHeaderCell(String text) => pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          color: primary,
          child: pw.Text(
            text,
            style: pw.TextStyle(font: fontBold, fontSize: 9, color: white),
          ),
        );

    pw.Widget tableCell(String text,
            {pw.TextStyle? style, pw.Alignment? align}) =>
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 8),
          alignment: align ?? pw.Alignment.centerLeft,
          child: pw.Text(text, style: style ?? body()),
        );

    pw.Widget sectionTitle(String text) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(height: 20),
            pw.Text(text, style: h2()),
            pw.SizedBox(height: 4),
            pw.Container(height: 2, width: 40, color: primary),
            pw.SizedBox(height: 10),
          ],
        );

    // ── 7-day trend table rows ──
    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final now0 = DateTime.now();
    List<pw.TableRow> trendRows = [];
    for (int i = 0; i < 7; i++) {
      final day = now0.subtract(Duration(days: 6 - i));
      final dayLabel =
          '${weekdays[day.weekday - 1]} ${day.day}/${day.month}';
      final rev = stats.weeklyTrend.length > i ? stats.weeklyTrend[i] : 0.0;
      trendRows.add(
        pw.TableRow(
          decoration: pw.BoxDecoration(
            color: i.isEven ? surface : white,
          ),
          children: [
            tableCell(dayLabel),
            tableCell(fmt(rev),
                align: pw.Alignment.centerRight,
                style: pw.TextStyle(
                  font: fontBold,
                  fontSize: 10,
                  color: rev > 0 ? primary : secondaryText,
                )),
          ],
        ),
      );
    }

    // ── Revenue by status ──
    final revCompleted = stats.revenueByStatus['Completed'] ?? 0.0;
    final revPending = stats.revenueByStatus['Pending'] ?? 0.0;
    final revOverdue = stats.revenueByStatus['Overdue'] ?? 0.0;

    // ── Page ──
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (context) => [
          // ── Header ──
          pw.Container(
            padding: const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(
              gradient: pw.LinearGradient(
                colors: [primary, const PdfColor.fromInt(0xFF4A00E0)],
                begin: pw.Alignment.topLeft,
                end: pw.Alignment.bottomRight,
              ),
              borderRadius: pw.BorderRadius.circular(12),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Financial Report', style: h1(white)),
                    pw.SizedBox(height: 4),
                    pw.Text(officeName,
                        style: pw.TextStyle(
                            font: fontMedium,
                            fontSize: 13,
                            color: white)),
                    pw.SizedBox(height: 4),
                    pw.Text('Period: ${stats.periodLabel}',
                        style: pw.TextStyle(
                            font: fontRegular,
                            fontSize: 10,
                            color: PdfColor(white.red, white.green, white.blue, 0.85))),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Generated',
                        style: pw.TextStyle(
                            font: fontRegular,
                            fontSize: 9,
                            color: white)),
                    pw.Text(reportDate,
                        style: pw.TextStyle(
                            font: fontBold,
                            fontSize: 12,
                            color: white)),
                  ],
                ),
              ],
            ),
          ),

          // ── KPI Cards ──
          sectionTitle('Summary'),
          pw.Row(
            children: [
              kpiCard('Total Revenue', fmt(stats.totalRevenue), primary),
              kpiCard('Total Orders', stats.totalOrders.toString(),
                  const PdfColor.fromInt(0xFF059669)),
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: surface,
                    borderRadius: pw.BorderRadius.circular(8),
                    border: pw.Border.all(
                        color: const PdfColor.fromInt(0xFFF59E0B), width: 2),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Avg. Order Value', style: label()),
                      pw.SizedBox(height: 6),
                      pw.Text(fmt(stats.averageOrderValue),
                          style: mono(const PdfColor.fromInt(0xFFF59E0B))),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // ── Revenue by Status ──
          sectionTitle('Revenue by Status'),
          pw.Table(
            border: pw.TableBorder.all(
                color: const PdfColor.fromInt(0xFFE5E7EB), width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(2),
              2: const pw.FlexColumnWidth(1.5),
            },
            children: [
              pw.TableRow(
                children: [
                  tableHeaderCell('Status'),
                  tableHeaderCell('Revenue'),
                  tableHeaderCell('% of Total'),
                ],
              ),
              _statusRow('Completed', revCompleted, stats.totalRevenue,
                  completed, fontBold, fontRegular),
              _statusRow('Pending', revPending, stats.totalRevenue, pending,
                  fontBold, fontRegular),
              _statusRow('Overdue', revOverdue, stats.totalRevenue, overdue,
                  fontBold, fontRegular),
            ],
          ),

          // ── 7-Day Revenue Trend ──
          sectionTitle('7-Day Revenue Trend'),
          pw.Table(
            border: pw.TableBorder.all(
                color: const PdfColor.fromInt(0xFFE5E7EB), width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(1.5),
            },
            children: [
              pw.TableRow(
                children: [
                  tableHeaderCell('Day'),
                  tableHeaderCell('Revenue'),
                ],
              ),
              ...trendRows,
            ],
          ),

          // ── Top Customers ──
          if (stats.topCustomers.isNotEmpty) ...[
            sectionTitle('Top Customers'),
            pw.Table(
              border: pw.TableBorder.all(
                  color: const PdfColor.fromInt(0xFFE5E7EB), width: 0.5),
              columnWidths: {
                0: const pw.FixedColumnWidth(30),
                1: const pw.FlexColumnWidth(3),
                2: const pw.FlexColumnWidth(2),
              },
              children: [
                pw.TableRow(
                  children: [
                    tableHeaderCell('#'),
                    tableHeaderCell('Customer'),
                    tableHeaderCell('Total Spent'),
                  ],
                ),
                ...stats.topCustomers.entries.toList().asMap().entries.map(
                  (entry) {
                    final idx = entry.key;
                    final customer = entry.value;
                    return pw.TableRow(
                      decoration: pw.BoxDecoration(
                          color: idx.isEven ? surface : white),
                      children: [
                        tableCell('${idx + 1}',
                            align: pw.Alignment.center,
                            style: pw.TextStyle(
                                font: fontBold,
                                fontSize: 10,
                                color: primary)),
                        tableCell(customer.key),
                        tableCell(fmt(customer.value),
                            align: pw.Alignment.centerRight,
                            style: pw.TextStyle(
                                font: fontBold,
                                fontSize: 10,
                                color: primary)),
                      ],
                    );
                  },
                ),
              ],
            ),
          ],

          // ── Footer spacer ──
          pw.SizedBox(height: 32),
          pw.Divider(color: const PdfColor.fromInt(0xFFE5E7EB)),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Powered by Sparkles Laundry',
                  style: pw.TextStyle(
                      font: fontMedium,
                      fontSize: 8,
                      color: secondaryText)),
              pw.Text('Confidential — For internal use only',
                  style: pw.TextStyle(
                      font: fontRegular,
                      fontSize: 8,
                      color: secondaryText)),
            ],
          ),
        ],
      ),
    );

    return pdf.save();
  }

  /// Opens the native OS share sheet for the PDF.
  static Future<void> sharePdf(Uint8List bytes, String filename) async {
    await Printing.sharePdf(
      bytes: bytes,
      filename: filename,
    );
  }

  /// Saves the PDF to the device's public Downloads directory (Android)
  /// or application Documents folder (iOS).
  /// Returns the saved file path.
  static Future<String> downloadPdf(Uint8List bytes, String filename) async {
    Directory? dir;
    if (Platform.isAndroid) {
      // Direct write to public downloads folder
      dir = Directory('/storage/emulated/0/Download');
      if (!await dir.exists()) {
        dir = await getDownloadsDirectory();
      }
    }
    dir ??= await getApplicationDocumentsDirectory();

    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  /// Generates the PDF and immediately opens the share sheet.
  static Future<void> generateAndShare(FinanceStats stats, String officeName) async {
    final bytes = await generatePdfBytes(stats, officeName);
    await sharePdf(bytes, '${officeName.replaceAll(' ', '_')}_financial_report.pdf');
  }

  static pw.TableRow _statusRow(
    String label,
    double value,
    double total,
    PdfColor dotColor,
    pw.Font bold,
    pw.Font regular,
  ) {
    final pct = total > 0 ? (value / total * 100).toStringAsFixed(1) : '0.0';
    final fmtVal =
        '₦${value.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+\.)'), (m) => '${m[1]},')}';
    return pw.TableRow(
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          child: pw.Row(
            children: [
              pw.Container(
                  width: 8,
                  height: 8,
                  decoration: pw.BoxDecoration(
                    color: dotColor,
                    shape: pw.BoxShape.circle,
                  )),
              pw.SizedBox(width: 6),
              pw.Text(label,
                  style: pw.TextStyle(font: regular, fontSize: 10)),
            ],
          ),
        ),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          alignment: pw.Alignment.centerRight,
          child: pw.Text(fmtVal,
              style: pw.TextStyle(font: bold, fontSize: 10, color: dotColor)),
        ),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          alignment: pw.Alignment.center,
          child: pw.Text('$pct%',
              style: pw.TextStyle(
                  font: regular,
                  fontSize: 10,
                  color: const PdfColor.fromInt(0xFF6B7280))),
        ),
      ],
    );
  }
}

/// Extension helper — PdfColor doesn't have a direct toColor();
/// this avoids the flatten() compile issue.
extension _PdfColorFlat on PdfColor {
  List<PdfColor> flatten() => [this];
}
