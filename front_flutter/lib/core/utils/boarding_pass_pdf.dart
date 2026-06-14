import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../shared/models/models.dart';

/// Genera y abre el PDF de tarjetas de abordaje.
/// Acepta la reserva y, opcionalmente, la factura para incluirla al final.
Future<void> printBoardingPasses(Reservation r, {Invoice? invoice}) async {
  final regular = await PdfGoogleFonts.notoSansRegular();
  final bold    = await PdfGoogleFonts.notoSansBold();

  final doc     = pw.Document(theme: pw.ThemeData.withFont(base: regular, bold: bold));
  final builder = _Builder(regular: regular, bold: bold);

  // 2 pasajeros por página
  for (var i = 0; i < r.passengers.length; i += 2) {
    final end   = (i + 2) < r.passengers.length ? i + 2 : r.passengers.length;
    final batch = r.passengers.sublist(i, end);

    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(30),
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          builder.pageHeader(r),
          pw.SizedBox(height: 20),
          ...batch.map((p) => pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 16),
            child: builder.ticketCard(r, p),
          )),
          if (i == 0 && invoice != null) ...[
            pw.Spacer(),
            builder.invoiceSection(invoice),
          ],
        ],
      ),
    ));
  }

  await Printing.layoutPdf(
    onLayout: (_) => doc.save(),
    name: 'AeroCore_${r.reservationCode}.pdf',
  );
}

// ── Builder interno ───────────────────────────────────────────────

class _Builder {
  final pw.Font regular;
  final pw.Font bold;

  static const _blue   = PdfColor(0.231, 0.510, 0.965);  // #3B82F6
  static const _navy   = PdfColor(0.059, 0.090, 0.165);  // #0F172A
  static const _navy2  = PdfColor(0.118, 0.231, 0.373);  // #1E3A5F
  static const _slate  = PdfColor(0.392, 0.455, 0.545);  // #64748B
  static const _light  = PdfColor(0.973, 0.980, 0.988);  // #F8FAFC
  static const _border = PdfColor(0.796, 0.835, 0.882);  // #CBD5E1
  static const _white  = PdfColors.white;

  _Builder({required this.regular, required this.bold});

  // ── Encabezado de página ────────────────────────────────────────
  pw.Widget pageHeader(Reservation r) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 22, vertical: 16),
    decoration: pw.BoxDecoration(
      gradient: const pw.LinearGradient(
        begin: pw.Alignment.topLeft,
        end:   pw.Alignment.bottomRight,
        colors: [_navy, _navy2],
      ),
      borderRadius: pw.BorderRadius.circular(12),
    ),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        // Logo
        pw.Row(children: [
          pw.Container(
            width: 34, height: 34,
            decoration: pw.BoxDecoration(
              color: _blue, borderRadius: pw.BorderRadius.circular(8)),
          ),
          pw.SizedBox(width: 10),
          pw.Text('AeroCore',
            style: pw.TextStyle(font: bold, color: _white, fontSize: 20)),
        ]),
        // Título + código
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          pw.Text('TARJETAS DE ABORDAJE',
            style: pw.TextStyle(font: bold, color: _white, fontSize: 9, letterSpacing: 2)),
          pw.SizedBox(height: 5),
          pw.Text('Reserva: ${r.reservationCode}',
            style: pw.TextStyle(
              font: regular, color: const PdfColor(0.68, 0.76, 0.88), fontSize: 12)),
        ]),
      ],
    ),
  );

  // ── Tarjeta de abordaje individual ─────────────────────────────
  pw.Widget ticketCard(Reservation r, Passenger p) {
    final f      = r.flight;
    final qrData = '${r.reservationCode}|${p.firstName} ${p.lastName}|${p.seatNumber ?? 'TBD'}';

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _border),
        borderRadius: pw.BorderRadius.circular(12),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          // ── Sección izquierda: vuelo + pasajero ──────────────
          pw.Expanded(
            flex: 3,
            child: pw.Container(
              padding: const pw.EdgeInsets.all(22),
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  right: pw.BorderSide(color: _border, width: 1)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Ruta IATA
                  pw.Row(children: [
                    pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                      pw.Text(f?.origin.iataCode ?? '---',
                        style: pw.TextStyle(font: bold, fontSize: 36, color: _navy)),
                      pw.Text(f?.origin.cityName ?? '',
                        style: pw.TextStyle(font: regular, fontSize: 10, color: _slate)),
                    ]),
                    pw.Expanded(child: pw.Column(
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      children: [
                        pw.SizedBox(height: 6),
                        pw.Text('- - - - - ->',
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(font: regular, fontSize: 11, color: _blue)),
                        pw.SizedBox(height: 4),
                        pw.Text(f?.airlineName ?? '',
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(font: regular, fontSize: 9, color: _slate)),
                      ],
                    )),
                    pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                      pw.Text(f?.destination.iataCode ?? '---',
                        style: pw.TextStyle(font: bold, fontSize: 36, color: _navy)),
                      pw.Text(f?.destination.cityName ?? '',
                        style: pw.TextStyle(font: regular, fontSize: 10, color: _slate)),
                    ]),
                  ]),
                  pw.SizedBox(height: 16),
                  pw.Divider(color: _border),
                  pw.SizedBox(height: 14),
                  // Grid de datos
                  pw.Row(children: [
                    pw.Expanded(child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _field('Pasajero', '${p.firstName} ${p.lastName}'),
                        pw.SizedBox(height: 10),
                        _field('Documento', p.documentNumber),
                        pw.SizedBox(height: 10),
                        _field('Clase', _cabinLabel(p.cabinClass)),
                      ],
                    )),
                    pw.SizedBox(width: 18),
                    pw.Expanded(child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        if (f != null) ...[
                          _field('Salida', f.depTime),
                          pw.SizedBox(height: 10),
                          _field('Llegada', f.arrTime),
                          pw.SizedBox(height: 10),
                        ],
                        _field('Estado', _statusLabel(r.status)),
                      ],
                    )),
                  ]),
                ],
              ),
            ),
          ),
          // ── Sección derecha: QR + asiento ────────────────────
          pw.Container(
            width: 136,
            color: _light,
            child: pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 22, horizontal: 18),
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: qrData,
                    width: 98, height: 98,
                    color: _navy,
                  ),
                  pw.SizedBox(height: 14),
                  pw.Text('ASIENTO', style: pw.TextStyle(
                    font: regular, fontSize: 8, color: _slate, letterSpacing: 1.8)),
                  pw.SizedBox(height: 5),
                  pw.Text(p.seatNumber ?? 'N/A',
                    style: pw.TextStyle(font: bold, fontSize: 28, color: _blue)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Sección de factura (pie de primera página) ─────────────────
  pw.Widget invoiceSection(Invoice inv) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    decoration: pw.BoxDecoration(
      color: _light,
      border: pw.Border.all(color: _border),
      borderRadius: pw.BorderRadius.circular(10),
    ),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        // Número de factura
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text('FACTURA', style: pw.TextStyle(
            font: regular, fontSize: 8, color: _slate, letterSpacing: 1.5)),
          pw.SizedBox(height: 4),
          pw.Text('#${inv.invoiceNumber}',
            style: pw.TextStyle(font: bold, fontSize: 14, color: _navy)),
          pw.Text(inv.createdAt.length >= 10 ? inv.createdAt.substring(0, 10) : '',
            style: pw.TextStyle(font: regular, fontSize: 9, color: _slate)),
        ]),
        // Montos
        pw.Row(children: [
          _amountCol('Subtotal',  '\$${inv.subtotal.toStringAsFixed(2)}'),
          pw.SizedBox(width: 24),
          _amountCol('IVA 15%',   '\$${inv.taxAmount.toStringAsFixed(2)}'),
          pw.SizedBox(width: 24),
          _amountCol('Total',     '\$${inv.total.toStringAsFixed(2)}', highlight: true),
        ]),
      ],
    ),
  );

  // ── Helpers ────────────────────────────────────────────────────
  pw.Widget _field(String label, String value) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(label.toUpperCase(), style: pw.TextStyle(
        font: regular, fontSize: 8, color: _slate, letterSpacing: 0.8)),
      pw.SizedBox(height: 3),
      pw.Text(value, style: pw.TextStyle(font: bold, fontSize: 12, color: _navy)),
    ],
  );

  pw.Widget _amountCol(String label, String value, {bool highlight = false}) =>
    pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
      pw.Text(label, style: pw.TextStyle(font: regular, fontSize: 9, color: _slate)),
      pw.SizedBox(height: 3),
      pw.Text(value, style: pw.TextStyle(
        font: bold, fontSize: 13,
        color: highlight ? _blue : _navy)),
    ]);

  String _cabinLabel(String? c) {
    if (c == 'FIRST')    return 'Primera Clase';
    if (c == 'BUSINESS') return 'Business';
    return 'Economica';
  }

  String _statusLabel(String s) {
    if (s == 'CONFIRMED') return 'Confirmada';
    if (s == 'CANCELLED') return 'Cancelada';
    return 'Pendiente';
  }
}