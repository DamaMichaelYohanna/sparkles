import 'dart:convert';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/order_model.dart';

class ReceiptGenerator {
  static Future<Uint8List> generateReceiptPdf(
    OrderModel order,
    List<Map<String, dynamic>> items,
  ) async {
    final pdf = pw.Document();
    
    // Load SharedPreferences data for Company Details
    final prefs = await SharedPreferences.getInstance();
    final companyName = prefs.getString('office_name') ?? 'My Laundry Co.';
    final companyAddress = prefs.getString('office_address') ?? '123 Clean St, Suite 4';
    final companyContact = prefs.getString('office_contact') ?? '+1 234 567 8900';

    final logoBase64 = prefs.getString('office_logo_base64');
    pw.MemoryImage? logoImage;
    if (logoBase64 != null && logoBase64.isNotEmpty) {
      try {
        logoImage = pw.MemoryImage(base64Decode(logoBase64));
      } catch (e) {
        print('Error decoding receipt logo: $e');
      }
    }

    // Calculate subtotal and discounts
    double itemsTotalDiscount = 0.0;
    
    for (var item in items) {
      final disc = (item['discount_amount'] as num?)?.toDouble() ?? 0.0;
      itemsTotalDiscount += disc;
    }

    final orderSubtotal = order.totalPrice + order.discountAmount;
    final totalDiscount = order.discountAmount + itemsTotalDiscount;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header section
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      if (logoImage != null) ...[
                        pw.Container(
                          width: 45,
                          height: 45,
                          margin: const pw.EdgeInsets.only(right: 12),
                          child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                        ),
                      ],
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            companyName,
                            style: pw.TextStyle(
                              fontSize: 18,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.blue900,
                            ),
                          ),
                          pw.SizedBox(height: 3),
                          pw.Text(companyAddress, style: const pw.TextStyle(fontSize: 8)),
                          pw.Text(companyContact, style: const pw.TextStyle(fontSize: 8)),
                        ],
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'RECEIPT',
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey700,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text('Order #${order.displayId}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text('Date: ${order.displayDate}', style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Divider(thickness: 1, color: PdfColors.grey300),
              pw.SizedBox(height: 10),

              // Customer Details
              pw.Text('Customer Info', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
              pw.SizedBox(height: 6),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Name: ${order.customerName}', style: const pw.TextStyle(fontSize: 10)),
                  if (order.customerPhone.isNotEmpty)
                    pw.Text('Phone: ${order.customerPhone}', style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Status: ${order.status}',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: order.status == 'Completed' ? PdfColors.green700 : PdfColors.orange700,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 20),

              // Items Table Header
              pw.Container(
                color: PdfColors.blue900,
                padding: const pw.EdgeInsets.all(6),
                child: pw.Row(
                  children: [
                    pw.Expanded(
                      flex: 3,
                      child: pw.Text('Item Description', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10)),
                    ),
                    pw.Expanded(
                      flex: 1,
                      child: pw.Text('Qty', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10), textAlign: pw.TextAlign.center),
                    ),
                    pw.Expanded(
                      flex: 1,
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.end,
                        children: [
                          pw.Text('Price (', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10)),
                          _nairaSign(style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10)),
                          pw.Text(')', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10)),
                        ],
                      ),
                    ),
                    pw.Expanded(
                      flex: 1,
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.end,
                        children: [
                          pw.Text('Disc (', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10)),
                          _nairaSign(style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10)),
                          pw.Text(')', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10)),
                        ],
                      ),
                    ),
                    pw.Expanded(
                      flex: 1,
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.end,
                        children: [
                          pw.Text('Sub (', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10)),
                          _nairaSign(style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10)),
                          pw.Text(')', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Items list rows
              pw.ListView.builder(
                itemCount: items.length,
                itemBuilder: (pw.Context context, int index) {
                  final item = items[index];
                  final name = item['item_name'] ?? 'Unknown Item';
                  final qty = item['quantity'] ?? 1;
                  final price = (item['unit_price'] as num?)?.toDouble() ?? 0.0;
                  final disc = (item['discount_amount'] as num?)?.toDouble() ?? 0.0;
                  final sub = (item['subtotal'] as num?)?.toDouble() ?? 0.0;

                  return pw.Container(
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(
                        bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
                      ),
                    ),
                    padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                    child: pw.Row(
                      children: [
                        pw.Expanded(
                          flex: 3,
                          child: pw.Text(name, style: const pw.TextStyle(fontSize: 10)),
                        ),
                        pw.Expanded(
                          flex: 1,
                          child: pw.Text('$qty', style: const pw.TextStyle(fontSize: 10), textAlign: pw.TextAlign.center),
                        ),
                        pw.Expanded(
                          flex: 1,
                          child: pw.Text(price.toStringAsFixed(2), style: const pw.TextStyle(fontSize: 10), textAlign: pw.TextAlign.right),
                        ),
                        pw.Expanded(
                          flex: 1,
                          child: pw.Text(disc > 0 ? disc.toStringAsFixed(2) : '-', style: const pw.TextStyle(fontSize: 10), textAlign: pw.TextAlign.right),
                        ),
                        pw.Expanded(
                          flex: 1,
                          child: pw.Text(sub.toStringAsFixed(2), style: const pw.TextStyle(fontSize: 10), textAlign: pw.TextAlign.right),
                        ),
                      ],
                    ),
                  );
                },
              ),
              
              pw.SizedBox(height: 20),

              // Summary block
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Notes:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      pw.SizedBox(height: 4),
                      pw.Text('All clothes are cleaned according to fabric standard.', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                      pw.Text('Please check items upon pickup.', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                    ],
                  ),
                  pw.Container(
                    width: 200,
                    child: pw.Column(
                      children: [
                        _buildSummaryRow('Subtotal', orderSubtotal),
                        if (totalDiscount > 0)
                          _buildSummaryRow('Discount', totalDiscount, isDiscount: true),
                        pw.Divider(thickness: 0.5, color: PdfColors.grey400),
                        _buildSummaryRow('Total Price', order.totalPrice, isBold: true),
                        _buildSummaryRow('Amount Paid', order.amountPaid),
                        pw.Divider(thickness: 1, color: PdfColors.blue900),
                        _buildSummaryRow(
                          'Balance Due',
                          (order.totalPrice - order.amountPaid),
                          isBold: true,
                          color: (order.totalPrice - order.amountPaid) > 0 ? PdfColors.red700 : PdfColors.green700,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              pw.Spacer(),

              // Footer
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text('Thank you for your business!', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                    pw.SizedBox(height: 4),
                    pw.Text('Clean clothes, happy life. Sparkles Laundry.', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildSummaryRow(String label, double amount, {bool isBold = false, bool isDiscount = false, PdfColor? color}) {
    final style = pw.TextStyle(
      fontSize: 9,
      fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
      color: color ?? (isDiscount ? PdfColors.red700 : PdfColors.black),
    );
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
          pw.Row(
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              if (isDiscount) pw.Text('- ', style: style),
              _nairaSign(style: style),
              pw.SizedBox(width: 1),
              pw.Text(amount.toStringAsFixed(2), style: style),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _nairaSign({pw.TextStyle? style}) {
    final double size = style?.fontSize ?? 10.0;
    final double strokeWidth = size * 0.07;
    final double gap = size * 0.15;
    final double lineLength = size * 0.65;
    
    return pw.Stack(
      alignment: pw.Alignment.center,
      children: [
        pw.Text('N', style: style),
        pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            pw.Container(width: lineLength, height: strokeWidth, color: style?.color ?? PdfColors.black),
            pw.SizedBox(height: gap),
            pw.Container(width: lineLength, height: strokeWidth, color: style?.color ?? PdfColors.black),
          ],
        ),
      ],
    );
  }
}
