import 'dart:typed_data';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:intl/intl.dart';
import '../models/printer_profile.dart';
import '../models/pos_models.dart';
import '../models/customer.dart';
import '../models/receipt_layout.dart';
import 'package:image/image.dart' as img;
import 'logo_cache_service.dart';
import '../models/store_settings.dart';
import '../utils/tenant_currency.dart';
import 'package:easy_localization/easy_localization.dart';

class ReceiptBuilder {
  Future<List<int>> buildReceipt({
    required PrinterProfile profile,
    required List<CartItem> items,
    required double total,
    double discountAmount = 0,
    Customer? customer,
    String? orderId,
    DateTime? date,
    ReceiptLayout? layout,
    dynamic storeSettings,
    Map<String, String>? contactInfos,
    String currencyCode = 'DZD',
    String? resolvedLogoUrl,
  }) async {
    final money = (storeSettings != null && storeSettings is StoreSettings)
        ? tenantCurrencyFormatter(storeSettings)
        : NumberFormat.simpleCurrency(name: currencyCode);
    final effectiveLayout = layout ?? ReceiptLayout.standard();

    final CapabilityProfile capabilityProfile = await _loadCapabilityProfile(
      profile,
    );
    final generator = Generator(
      profile.paperWidth == 58 ? PaperSize.mm58 : PaperSize.mm80,
      capabilityProfile,
    );

    List<int> bytes = [];
    final safeContactInfos = contactInfos ?? {};
    
    final storeName = effectiveLayout.storeNameOverride ?? storeSettings?.name ?? 'MySaaS Store';
    final storeAddress = effectiveLayout.storeAddressOverride ?? safeContactInfos['address'];
    final storePhone = effectiveLayout.storePhoneOverride ?? safeContactInfos['phone'];
    final storeEmail = effectiveLayout.storeEmailOverride ?? safeContactInfos['email'];
    final logoUrl = resolvedLogoUrl ?? storeSettings?.logoUrl;

    // 1. Header
    
    if (effectiveLayout.showLogo && logoUrl != null && logoUrl.isNotEmpty) {
      final cachedLogo = await logoCacheService.cacheLogo(logoUrl);
      if (cachedLogo != null && await cachedLogo.exists()) {
        try {
          final bytesData = await cachedLogo.readAsBytes();
          final image = img.decodeImage(bytesData);
          if (image != null) {
            bytes += generator.image(image);
            bytes += generator.feed(1);
          }
        } catch (_) {}
      }
    }
    
    if (effectiveLayout.showStoreName) {
      bytes += generator.text(
        storeName,
        styles: const PosStyles(
          align: PosAlign.center,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
          bold: true,
        ),
      );
      bytes += generator.feed(1);
    }
    
    if (effectiveLayout.showStoreAddress && storeAddress != null && storeAddress.isNotEmpty) {
      bytes += generator.text(storeAddress, styles: const PosStyles(align: PosAlign.center));
    }
    if (effectiveLayout.showStorePhone && storePhone != null && storePhone.isNotEmpty) {
      bytes += generator.text('Tel: $storePhone', styles: const PosStyles(align: PosAlign.center));
    }
    if (effectiveLayout.showStoreEmail && storeEmail != null && storeEmail.isNotEmpty) {
      bytes += generator.text('Email: $storeEmail', styles: const PosStyles(align: PosAlign.center));
    }
    
    if (effectiveLayout.showStoreAddress || effectiveLayout.showStorePhone || effectiveLayout.showStoreEmail) {
      bytes += generator.feed(1);
    }

    if (effectiveLayout.showHeader && effectiveLayout.headerText.isNotEmpty) {
      bytes += generator.text(
        effectiveLayout.headerText,
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
        ),
      );
      bytes += generator.feed(1);
    }

    if (effectiveLayout.showOrderNumber && orderId != null) {
      bytes += generator.text(
        'Order #$orderId',
        styles: const PosStyles(align: PosAlign.center),
      );
    }

    if (effectiveLayout.showDate) {
      bytes += generator.text(
        DateFormat('dd/MM/yyyy HH:mm').format(date ?? DateTime.now()),
        styles: const PosStyles(align: PosAlign.center),
      );
    }

    // Customer Info
    if (effectiveLayout.showCustomerInfo && customer != null) {
      bytes += generator.feed(1);
      bytes += generator.text('Customer: ${customer.name}');
      if (customer.phone.isNotEmpty) {
        bytes += generator.text('Phone: ${customer.phone}');
      }
    }

    bytes += generator.feed(1);
    bytes += generator.hr();

    // 2. Items
    if (profile.paperWidth == 58) {
      // 58mm Layout
      for (var item in items) {
        bytes += generator.text(
          item.name +
              (item.variantTitle != null ? ' (${item.variantTitle})' : ''),
          styles: const PosStyles(bold: true),
        );
        bytes += generator.row([
          PosColumn(
            text: '${item.quantity} x ${money.format(item.price)}',
            width: 8,
          ),
          PosColumn(
            text: money.format(item.price * item.quantity),
            width: 4,
            styles: const PosStyles(align: PosAlign.right),
          ),
        ]);
      }
    } else {
      // 80mm Layout
      bytes += generator.row([
        PosColumn(text: 'app.item'.tr(), width: 6, styles: const PosStyles(bold: true)),
        PosColumn(
          text: 'admin.pages.sales.detail.itemsTable.qty'.tr(),
          width: 2,
          styles: const PosStyles(bold: true, align: PosAlign.center),
        ),
        PosColumn(
          text: 'admin.pages.sales.detail.itemsTable.price'.tr(),
          width: 2,
          styles: const PosStyles(bold: true, align: PosAlign.right),
        ),
        PosColumn(
          text: 'admin.pages.sales.detail.itemsTable.total'.tr(),
          width: 2,
          styles: const PosStyles(bold: true, align: PosAlign.right),
        ),
      ]);
      bytes += generator.hr();

      for (var item in items) {
        String name =
            item.name +
            (item.variantTitle != null ? ' (${item.variantTitle})' : '');
        bytes += generator.row([
          PosColumn(text: name, width: 6),
          PosColumn(
            text: item.quantity.toString(),
            width: 2,
            styles: const PosStyles(align: PosAlign.center),
          ),
          PosColumn(
            text: money.format(item.price),
            width: 2,
            styles: const PosStyles(align: PosAlign.right),
          ),
          PosColumn(
            text: money.format(item.price * item.quantity),
            width: 2,
            styles: const PosStyles(align: PosAlign.right),
          ),
        ]);
      }
    }

    bytes += generator.hr();

    // 3. Totals
    if (discountAmount > 0) {
      bytes += generator.row([
        PosColumn(
          text: 'admin.pages.pos.catalog.actions.discount'.tr(),
          width: 6,
          styles: const PosStyles(bold: true),
        ),
        PosColumn(
          text: '-${money.format(discountAmount)}',
          width: 6,
          styles: const PosStyles(align: PosAlign.right, bold: true),
        ),
      ]);
    }

    bytes += generator.row([
      PosColumn(
        text: 'admin.pages.sales.detail.itemsTable.total'.tr(),
        width: 6,
        styles: const PosStyles(
          height: PosTextSize.size2,
          width: PosTextSize.size2,
          bold: true,
        ),
      ),
      PosColumn(
        text: money.format(total),
        width: 6,
        styles: const PosStyles(
          height: PosTextSize.size2,
          width: PosTextSize.size2,
          bold: true,
          align: PosAlign.right,
        ),
      ),
    ]);

    bytes += generator.feed(2);
    if (effectiveLayout.showFooter) {
      bytes += generator.text(
        effectiveLayout.footerText,
        styles: const PosStyles(align: PosAlign.center, bold: true),
      );
    }
    
    if (effectiveLayout.showOrderNumber && orderId != null) {
      bytes += generator.feed(1);
      try {
        final List<int> barcodeData = orderId.codeUnits;
        bytes += generator.barcode(Barcode.code128(barcodeData));
        bytes += generator.text(orderId, styles: const PosStyles(align: PosAlign.center));
      } catch (e) {
        // Fallback if barcode fails
        bytes += generator.text(orderId, styles: const PosStyles(align: PosAlign.center));
      }
    }
    
    if (profile.feedLines > 0) {
      bytes += generator.feed(profile.feedLines);
    }

    // 4. Cut & Drawer
    if (profile.cut) {
      bytes += generator.cut();
    }
    if (profile.drawer) {
      bytes += generator.drawer();
    }

    return bytes;
  }

  Future<List<int>> buildImageReceipt({
    required PrinterProfile profile,
    required List<List<int>> images,
  }) async {
    final CapabilityProfile capabilityProfile = await _loadCapabilityProfile(
      profile,
    );
    final generator = Generator(
      profile.paperWidth == 58 ? PaperSize.mm58 : PaperSize.mm80,
      capabilityProfile,
    );

    List<int> bytes = [];

    for (final imageBytes in images) {
      final image = img.decodeImage(Uint8List.fromList(imageBytes));
      if (image != null) {
        bytes += generator.image(image);
      }
    }

    if (profile.cut) {
      bytes += generator.cut();
    }
    if (profile.drawer) {
      bytes += generator.drawer();
    }

    return bytes;
  }

  /// Loads the ESC/POS capability profile configured on [profile].
  ///
  /// An unknown profile name must not stop a sale from printing, so we fall
  /// back to the generic profile instead of letting the load throw.
  Future<CapabilityProfile> _loadCapabilityProfile(
    PrinterProfile profile,
  ) async {
    final name = profile.capabilityProfileName;
    try {
      return await CapabilityProfile.load(name: name);
    } catch (_) {
      return CapabilityProfile.load(name: 'default');
    }
  }
}
