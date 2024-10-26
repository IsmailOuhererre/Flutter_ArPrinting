import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:esc_pos_printer_plus/esc_pos_printer_plus.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'language_provider.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => LanguageProvider(),
      child: const PrinterApp(),
    ),
  );
}

class PrinterApp extends StatelessWidget {
  const PrinterApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Epson Printer',
      theme: ThemeData(),
      locale: Provider.of<LanguageProvider>(context).locale,
      debugShowCheckedModeBanner: false,
      home: const PrinterScreen(),
      builder: (context, child) {
        final locale = Provider.of<LanguageProvider>(context).locale;
        return Directionality(
          textDirection: locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr,
          child: child!,
        );
      },
    );
  }
}

class PrinterScreen extends StatefulWidget {
  const PrinterScreen({Key? key}) : super(key: key);

  @override
  State<PrinterScreen> createState() => _PrinterScreenState();
}

class _PrinterScreenState extends State<PrinterScreen> {
  final TextEditingController ipController = TextEditingController();
  final TextEditingController textController = TextEditingController();
  bool isPrinting = false;
  bool isGeneratingPdf = false; // Track PDF generation state
  String printerStatus = 'Not Connected';

  Future<void> printReceipt() async {
    if (ipController.text.isEmpty || textController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter IP and text')),
      );
      return;
    }

    setState(() {
      isPrinting = true;
      printerStatus = 'Connecting...';
    });

    try {
      final profile = await CapabilityProfile.load();
      final printer = NetworkPrinter(PaperSize.mm80, profile);

      setState(() => printerStatus = 'Connecting to printer...');

      final PosPrintResult connect = await printer.connect(
        ipController.text,
        port: 9100,
        timeout: const Duration(seconds: 5),
      );

      if (connect != PosPrintResult.success) {
        throw Exception('Failed to connect to printer: ${connect.msg}');
      }

      setState(() => printerStatus = 'Printing...');

      bool isArabic = RegExp(r'[\u0600-\u06FF]').hasMatch(textController.text);

      printer.text(
        textController.text,
        styles: PosStyles(
          align: isArabic ? PosAlign.right : PosAlign.left,
          width: PosTextSize.size1,
          height: PosTextSize.size1,
        ),
      );

      printer.feed(4);
      printer.cut();

      printer.disconnect();

      if (mounted) {
        setState(() => printerStatus = 'Print completed');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Printed successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => printerStatus = 'Error: ${e.toString()}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isPrinting = false);
      }
    }
  }

  Future<void> generatePdf() async {
    if (textController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter text to generate PDF')),
      );
      return;
    }

    setState(() {
      isGeneratingPdf = true; // Show loading indicator
    });

    try {
      final pdf = pw.Document();

      // Load the Arabic font
      final pdfFont = await PdfGoogleFonts.notoNaskhArabicRegular();

      pdf.addPage(
        pw.Page(
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Text(
                textController.text,
                style: pw.TextStyle(
                  font: pdfFont,
                  fontSize: 40,
                ),
                textDirection: textController.text.contains(RegExp(r'[\u0600-\u06FF]'))
                    ? pw.TextDirection.rtl
                    : pw.TextDirection.ltr,
              ),
            );
          },
        ),
      );

      final Uint8List pdfData = await pdf.save();
      await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdfData);

      setState(() {
        isGeneratingPdf = false; // Hide loading indicator
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF generated successfully')),
        );
      });
    } catch (e) {
      if (mounted) {
        setState(() => isGeneratingPdf = false); // Hide loading indicator
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating PDF: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Epson TM-T30 Printer'),
        actions: [
          IconButton(
            icon: Icon(
              Provider.of<LanguageProvider>(context).locale.languageCode == 'ar'
                  ? Icons.language
                  : Icons.language_outlined,
            ),
            onPressed: () {
              Provider.of<LanguageProvider>(context, listen: false).switchLanguage();
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text(
                      'Printer Status',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(printerStatus),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ipController,
              decoration: InputDecoration(
                labelText: Provider.of<LanguageProvider>(context).locale.languageCode == 'ar'
                    ? 'عنوان IP للطابعة'
                    : 'Printer IP Address',
                hintText: Provider.of<LanguageProvider>(context).locale.languageCode == 'ar'
                    ? 'مثال: 192.168.1.100'
                    : 'Example: 192.168.1.100',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.wifi),
              ),
              enabled: !isPrinting,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: textController,
              decoration: InputDecoration(
                labelText: Provider.of<LanguageProvider>(context).locale.languageCode == 'ar'
                    ? 'النص للطباعة'
                    : 'Text to Print',
                hintText: Provider.of<LanguageProvider>(context).locale.languageCode == 'ar'
                    ? 'أدخل النص للطباعة'
                    : 'Enter text to print',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.text_fields),
              ),
              maxLines: 5,
              enabled: !isPrinting,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: isPrinting ? null : printReceipt,
              icon: Icon(isPrinting ? Icons.hourglass_empty : Icons.print),
              label: Text(isPrinting
                  ? Provider.of<LanguageProvider>(context).locale.languageCode == 'ar'
                      ? 'يتم الطباعة...'
                      : 'Printing...'
                  : Provider.of<LanguageProvider>(context).locale.languageCode == 'ar'
                      ? 'طباعة'
                      : 'Print'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16.0),
                backgroundColor: isPrinting ? Colors.grey : const Color.fromARGB(255, 177, 181, 255),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: isGeneratingPdf ? null : generatePdf, // Disable if generating PDF
              icon: const Icon(Icons.picture_as_pdf),
              label: Text(Provider.of<LanguageProvider>(context).locale.languageCode == 'ar'
                  ? 'إنشاء PDF'
                  : 'Generate PDF'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16.0),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    ipController.dispose();
    textController.dispose();
    super.dispose();
  }
}
