import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/prescription_model.dart';

class PrescriptionPdfService {
  static Future<Uint8List> generatePdf(PrescriptionModel rx) async {
    final pdf = pw.Document();

    pw.Font? bengaliFont;
    try {
      final fontData = await rootBundle.load('assets/fonts/NotoSansBengali.ttf');
      bengaliFont = pw.Font.ttf(fontData);
    } catch (e) {
      debugPrint('NotoSansBengali font could not be loaded, using default: $e');
    }

    final baseTheme = bengaliFont != null
        ? pw.ThemeData.withFont(
            base: bengaliFont,
            bold: bengaliFont,
            italic: bengaliFont,
            boldItalic: bengaliFont,
          )
        : pw.ThemeData.base();

    final dateStr = rx.createdAt != null
        ? '${rx.createdAt!.day.toString().padLeft(2, '0')}/${rx.createdAt!.month.toString().padLeft(2, '0')}/${rx.createdAt!.year}'
        : 'Not found - confirm with patient';

    final followUpStr = rx.followUpDate != null
        ? '${rx.followUpDate!.day.toString().padLeft(2, '0')}/${rx.followUpDate!.month.toString().padLeft(2, '0')}/${rx.followUpDate!.year}'
        : null;

    final deptStr = rx.studentDepartment?.trim().isNotEmpty == true
        ? rx.studentDepartment!
        : 'Not found - confirm with patient';

    final bloodStr = rx.studentBloodGroup?.trim().isNotEmpty == true
        ? '${rx.studentBloodGroup} (Unverified)'
        : 'Unverified';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        theme: baseTheme,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // ==========================================
              // HEADER: BAUST Medical Center
              // ==========================================
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'BAUST Medical Center',
                        style: pw.TextStyle(
                          fontSize: 22,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blueGrey900,
                        ),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        'Bangladesh Army University of Science and Technology, Saidpur',
                        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                      ),
                      pw.Text(
                        'Official Digital Clinical Prescription',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.teal800,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Date: $dateStr',
                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Rx ID: ${rx.id}',
                        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                      ),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 10),
              pw.Divider(thickness: 1.5, color: PdfColors.teal800),
              pw.SizedBox(height: 10),

              // ==========================================
              // PATIENT DETAILS CARD
              // ==========================================
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  border: pw.Border.all(color: PdfColors.grey300),
                ),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      flex: 3,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Patient Name: ${rx.studentName}',
                            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            'Student ID / Roll: ${rx.studentId}',
                            style: const pw.TextStyle(fontSize: 10),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            'Department: $deptStr',
                            style: const pw.TextStyle(fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                    pw.Expanded(
                      flex: 2,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Blood Group: $bloodStr',
                            style: const pw.TextStyle(fontSize: 10),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            rx.source == 'scan'
                                ? 'Clinical Source: Digitized from paper'
                                : 'Clinical Source: Digital (Smart Medi)',
                            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 12),

              // ==========================================
              // CLINICAL DIAGNOSIS
              // ==========================================
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue50,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                  border: pw.Border.all(color: PdfColors.blue200),
                ),
                child: pw.Row(
                  children: [
                    pw.Text(
                      'Diagnosis: ',
                      style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
                    ),
                    pw.Expanded(
                      child: pw.Text(
                        rx.diagnosis,
                        style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 14),

              // ==========================================
              // RX LIST (MEDICATIONS)
              // ==========================================
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(
                    'Rx',
                    style: pw.TextStyle(
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.teal900,
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Text(
                    'Prescribed Medicines',
                    style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
                  ),
                ],
              ),
              pw.SizedBox(height: 6),

              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.8),
                columnWidths: {
                  0: const pw.FixedColumnWidth(24),
                  1: const pw.FlexColumnWidth(3),
                  2: const pw.FlexColumnWidth(1.5),
                  3: const pw.FlexColumnWidth(1.5),
                  4: const pw.FlexColumnWidth(1.5),
                  5: const pw.FlexColumnWidth(2.5),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.teal50),
                    children: [
                      _buildTableCell('#', isHeader: true),
                      _buildTableCell('Medicine Name', isHeader: true),
                      _buildTableCell('Dose', isHeader: true),
                      _buildTableCell('Frequency', isHeader: true),
                      _buildTableCell('Duration', isHeader: true),
                      _buildTableCell('Instructions', isHeader: true),
                    ],
                  ),
                  for (int i = 0; i < rx.items.length; i++)
                    pw.TableRow(
                      decoration: pw.BoxDecoration(
                        color: i % 2 == 0 ? PdfColors.white : PdfColors.grey50,
                      ),
                      children: [
                        _buildTableCell('${i + 1}'),
                        _buildTableCell(rx.items[i].name, isBold: true),
                        _buildTableCell(rx.items[i].dose),
                        _buildTableCell(rx.items[i].frequency),
                        _buildTableCell(rx.items[i].duration),
                        _buildTableCell(rx.items[i].instructions ?? '-'),
                      ],
                    ),
                ],
              ),

              pw.SizedBox(height: 14),

              // ==========================================
              // ADVICE / INSTRUCTIONS (OPTIONAL)
              // ==========================================
              if (rx.advice != null && rx.advice!.trim().isNotEmpty) ...[
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey50,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                    border: pw.Border.all(color: PdfColors.grey300),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Advice / Instructions:',
                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        rx.advice!.trim(),
                        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey900),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 10),
              ],

              // ==========================================
              // FOLLOW-UP DATE (OPTIONAL)
              // ==========================================
              if (followUpStr != null) ...[
                pw.Row(
                  children: [
                    pw.Text(
                      'Next Follow-up Consultation: ',
                      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.teal900),
                    ),
                    pw.Text(
                      followUpStr,
                      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.teal900),
                    ),
                  ],
                ),
                pw.SizedBox(height: 14),
              ],

              pw.Spacer(),

              // ==========================================
              // DOCTOR SIGNATURE & FOOTER
              // ==========================================
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Smart Medi — BAUST Emergency & Clinical System',
                        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        rx.source == 'scan'
                            ? 'Digitized from paper prescription via Smart Medi - ID ${rx.id}'
                            : 'Digitally issued via Smart Medi - ID ${rx.id}',
                        style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Container(
                        width: 140,
                        decoration: const pw.BoxDecoration(
                          border: pw.Border(top: pw.BorderSide(color: PdfColors.grey400, width: 1)),
                        ),
                        padding: const pw.EdgeInsets.only(top: 4),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            pw.Text(
                              'Dr. ${rx.doctorName}',
                              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                            ),
                            pw.Text(
                              rx.doctorDesignation,
                              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                            ),
                            pw.Text(
                              'BAUST Medical Center',
                              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildTableCell(String text, {bool isHeader = false, bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 8.5 : 8,
          fontWeight: isHeader || isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isHeader ? PdfColors.teal900 : PdfColors.black,
        ),
      ),
    );
  }

  static Future<void> printOrShare(PrescriptionModel rx) async {
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => generatePdf(rx),
      name: 'Prescription_${rx.studentId}_${rx.id}.pdf',
    );
  }
}
