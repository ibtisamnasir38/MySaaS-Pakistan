import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:uuid/uuid.dart';
import '../../providers/printer_profiles_provider.dart';
import '../../models/printer_profile.dart';
import '../../services/discovery_service.dart';
import '../../services/print_service.dart';
import '../../utils/printer_validators.dart';
import '../../widgets/form/form_input.dart';
import '../../widgets/form/form_select.dart';
import '../../widgets/dialogs/app_dialog.dart';
import '../../widgets/buttons/app_button.dart';
import 'receipt_layout_editor.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../models/pos_models.dart'; // For CartItem
import 'package:easy_localization/easy_localization.dart';
import '../../utils/app_toasts.dart';

class PrintersSettingsPage extends ConsumerStatefulWidget {
  const PrintersSettingsPage({super.key});

  @override
  ConsumerState<PrintersSettingsPage> createState() =>
      _PrintersSettingsPageState();
}

class _PrintersSettingsPageState extends ConsumerState<PrintersSettingsPage> {
  // View State
  bool _isEditing = false;
  PrinterProfile? _editingProfile;
  bool _isTestingConnection = false;
  bool _isTestPrinting = false;

  // Form State
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _ipController;
  late TextEditingController _portController;
  late TextEditingController _macController;
  late TextEditingController _deviceIdController;
  late TextEditingController _printerNameController;
  late TextEditingController _portNameController;

  PrinterTransport _transport = PrinterTransport.network;
  int _paperWidth = 80;
  bool _cut = true;
  bool _drawer = false;
  bool _forceImagePrint = false;
  int _copies = 1;
  int _feedLines = PrinterProfile.defaultFeedLines;
  int _baudRate = 9600;
  String _capabilityProfile = 'default';
  bool _makeDefault = false;

  List<PrinterCapabilityProfile> _capabilityProfiles =
      PrinterProfile.fallbackCapabilityProfiles;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadCapabilityProfiles();
  }

  void _initializeControllers() {
    _nameController = TextEditingController();
    _ipController = TextEditingController();
    _portController = TextEditingController(text: '9100');
    _macController = TextEditingController();
    _deviceIdController = TextEditingController();
    _printerNameController = TextEditingController();
    _portNameController = TextEditingController();
  }

  Future<void> _loadCapabilityProfiles() async {
    final profiles = await DiscoveryService.getCapabilityProfiles();
    if (!mounted) return;
    setState(() => _capabilityProfiles = profiles);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ipController.dispose();
    _portController.dispose();
    _macController.dispose();
    _deviceIdController.dispose();
    _printerNameController.dispose();
    _portNameController.dispose();
    super.dispose();
  }

  void _startEditing([PrinterProfile? profile]) {
    final defaultProfileId = ref.read(printerProfilesProvider).defaultProfile?.id;

    setState(() {
      _isEditing = true;
      _editingProfile = profile;
      _isTestingConnection = false;
      _isTestPrinting = false;

      if (profile != null) {
        _nameController.text = profile.name;
        _transport = profile.transport;
        _paperWidth = profile.paperWidth;
        _cut = profile.cut;
        _drawer = profile.drawer;
        _forceImagePrint = profile.forceImagePrint;
        _copies = profile.copies;
        _feedLines = profile.feedLines;
        _baudRate = _nearestBaudRate(profile.baudRate);
        _capabilityProfile = profile.capabilityProfileName;
        _makeDefault = defaultProfileId == profile.id;

        _ipController.text = profile.ip ?? '';
        _portController.text = profile.port?.toString() ?? '9100';
        _macController.text = profile.macAddress ?? '';
        _deviceIdController.text = profile.deviceId ?? '';
        _printerNameController.text = profile.printerName ?? '';
        _portNameController.text = profile.portName ?? '';
      } else {
        // Reset for new
        _nameController.clear();
        _transport = PrinterTransport.network;
        _paperWidth = 80;
        _cut = true;
        _drawer = false;
        _forceImagePrint = false;
        _copies = 1;
        _feedLines = PrinterProfile.defaultFeedLines;
        _baudRate = 9600;
        _capabilityProfile = 'default';
        // First printer configured becomes the default automatically.
        _makeDefault = defaultProfileId == null;
        _ipController.clear();
        _portController.text = '9100';
        _macController.clear();
        _deviceIdController.clear();
        _printerNameController.clear();
        _portNameController.clear();
      }
    });
  }

  int _nearestBaudRate(int? value) {
    if (value == null) return 9600;
    return PrinterProfile.supportedBaudRates.contains(value) ? value : 9600;
  }

  void _cancelEditing() {
    setState(() {
      _isEditing = false;
      _editingProfile = null;
    });
  }

  /// Builds the profile currently described by the form, preserving any
  /// capability keys this screen does not expose.
  PrinterProfile _buildProfileFromForm() {
    final connectionParams = <String, dynamic>{};

    switch (_transport) {
      case PrinterTransport.network:
        connectionParams['ip'] = _ipController.text.trim();
        connectionParams['port'] =
            int.tryParse(_portController.text.trim()) ?? 9100;
        break;
      case PrinterTransport.bluetooth:
        final mac = _macController.text.trim();
        connectionParams['macAddress'] =
            PrinterValidators.normalizeMacAddress(mac) ?? mac;
        break;
      case PrinterTransport.ble:
        connectionParams['deviceId'] = _deviceIdController.text.trim();
        break;
      case PrinterTransport.windows:
        connectionParams['printerName'] = _printerNameController.text.trim();
        break;
      case PrinterTransport.serial:
        connectionParams['portName'] = _portNameController.text.trim();
        connectionParams['baudRate'] = _baudRate;
        break;
      case PrinterTransport.pdf:
        break;
    }

    final capabilityParams = <String, dynamic>{
      ...?_editingProfile?.capabilityParams,
      'paperWidth': _paperWidth,
      'cut': _cut,
      'drawer': _drawer,
      'forceImagePrint': _forceImagePrint,
      'copies': _copies,
      'feedLines': _feedLines,
      'capabilityProfile': _capabilityProfile,
    };

    return PrinterProfile(
      id: _editingProfile?.id ?? const Uuid().v4(),
      name: _nameController.text.trim(),
      transport: _transport,
      connectionParams: connectionParams,
      capabilityParams: capabilityParams,
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final profile = _buildProfileFromForm();
    final notifier = ref.read(printerProfilesProvider.notifier);
    final wasCreating = _editingProfile == null;

    try {
      if (wasCreating) {
        final created = await notifier.addProfile(profile);
        if (_makeDefault) await notifier.setDefaultProfile(created.id);
      } else {
        await notifier.updateProfile(profile);
        final isDefault =
            ref.read(printerProfilesProvider).defaultProfile?.id == profile.id;
        if (_makeDefault && !isDefault) {
          await notifier.setDefaultProfile(profile.id);
        } else if (!_makeDefault && isDefault) {
          await notifier.setDefaultProfile(null);
        }
      }
    } catch (e) {
      if (!mounted) return;
      AppToasts.show(
        context,
        'app.printer_save_failed'.tr(),
        description: e.toString(),
        type: AppToastType.error,
      );
      return;
    }

    if (!mounted) return;
    _cancelEditing();
    AppToasts.show(
      context,
      'app.printer_saved_successfully'.tr(),
      type: AppToastType.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    const accentColor = Color(0xFF65A30D); // Lime 600

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isEditing) _buildEditingHeader() else _buildMainHeader(),
          const SizedBox(height: 24),
          if (_isEditing) _buildForm(accentColor) else _buildList(accentColor),
        ],
      ),
    );
  }

  Widget _buildMainHeader() {
    final isLoading = ref.watch(printerProfilesProvider).isLoading;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'app.printer_settings'.tr(),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.5,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'app.manage_your_receipt_printers_a'.tr(),
                style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: isLoading
              ? null
              : () => ref
                    .read(printerProfilesProvider.notifier)
                    .loadProfiles(forceRefresh: true),
          icon: const Icon(LucideIcons.refreshCcw, color: Color(0xFF64748B)),
          tooltip: 'app.printer_refresh_list'.tr(),
        ),
      ],
    );
  }

  Widget _buildEditingHeader() {
    return Row(
      children: [
        IconButton(
          onPressed: _cancelEditing,
          icon: const Icon(LucideIcons.arrowLeft, color: Color(0xFF0F172A)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            _editingProfile == null
                ? 'app.add_printer'.tr()
                : 'app.edit_printer'.tr(),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.5,
              color: Color(0xFF0F172A),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildList(Color accentColor) {
    final profilesState = ref.watch(printerProfilesProvider);

    if (profilesState.isLoading && profilesState.profiles.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 64),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (profilesState.profiles.isEmpty) {
      return Column(
        children: [
          if (profilesState.errorMessage != null) ...[
            _buildErrorBanner(profilesState.errorMessage!),
            const SizedBox(height: 24),
          ],
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Icon(
                    LucideIcons.printer,
                    size: 64,
                    color: Colors.grey[300],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'app.no_printers_configured'.tr(),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'app.add_a_printer_to_start_printin'.tr(),
                  style: TextStyle(color: Colors.grey[500]),
                ),
                const SizedBox(height: 32),
                AppButton.primary(
                  label: 'app.add_printer'.tr(),
                  icon: LucideIcons.plus,
                  onPressed: () => _startEditing(),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        if (profilesState.errorMessage != null) ...[
          _buildErrorBanner(profilesState.errorMessage!),
          const SizedBox(height: 16),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'app.saved_printers'.tr(),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF334155),
              ),
            ),
            AppButton.primary(
              label: 'app.add_new'.tr(),
              icon: LucideIcons.plus,
              onPressed: () => _startEditing(),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Layout Editor Link
        Card(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                LucideIcons.layoutTemplate,
                color: Colors.amber.shade700,
              ),
            ),
            title: Text(
              'app.receipt_layout_configuration'.tr(),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('app.customize_your_receipt_header'.tr()),
            trailing: const Icon(LucideIcons.chevronRight),
            onTap: () {
              // Open Layout Editor
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ReceiptLayoutEditor(
                    initialLayout: profilesState.receiptLayout,
                    onSave: (layout) {
                      ref
                          .read(printerProfilesProvider.notifier)
                          .saveLayout(layout);
                      AppToasts.show(context, 'app.layout_saved'.tr());
                      Navigator.pop(context);
                    },
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
        ...profilesState.profiles.map(
          (profile) => _buildProfileCard(
            profile,
            profilesState.defaultProfile?.id == profile.id,
            accentColor,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.triangleAlert, color: Colors.red.shade400, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'app.printer_load_failed'.tr(),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.red.shade700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: TextStyle(fontSize: 12, color: Colors.red.shade400),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          AppButton.secondary(
            label: 'app.retry'.tr(),
            onPressed: () => ref
                .read(printerProfilesProvider.notifier)
                .loadProfiles(forceRefresh: true),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard(
    PrinterProfile profile,
    bool isDefault,
    Color accentColor,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDefault ? accentColor : Colors.transparent,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDefault
                ? accentColor.withValues(alpha: 0.1)
                : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            _getIconForTransport(profile.transport),
            color: isDefault ? accentColor : const Color(0xFF64748B),
          ),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                profile.name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            if (isDefault) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'admin.pages.sales.detail.itemsTable.defaultVariant'.tr(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoBadge(
                _getIconForTransport(profile.transport),
                _transportLabel(profile.transport),
              ),
              const SizedBox(height: 4),
              _buildInfoBadge(LucideIcons.link, _getConnectionSummary(profile)),
              const SizedBox(height: 4),
              _buildInfoBadge(
                LucideIcons.settings2,
                _getCapabilitySummary(profile),
              ),
            ],
          ),
        ),
        trailing: PopupMenuButton(
          icon: const Icon(LucideIcons.moreVertical, color: Color(0xFF94A3B8)),
          itemBuilder: (context) => [
            PopupMenuItem(value: 'edit', child: Text('app.edit_config'.tr())),
            if (!isDefault)
              PopupMenuItem(
                value: 'default',
                child: Text('app.set_as_default'.tr()),
              ),
            PopupMenuItem(
              value: 'test_connection',
              child: Text('app.printer_test_connection'.tr()),
            ),
            PopupMenuItem(value: 'test', child: Text('app.test_print'.tr())),
            PopupMenuItem(value: 'duplicate', child: Text('app.duplicate'.tr())),
            PopupMenuItem(
              value: 'delete',
              child: Text(
                'admin.pages.products.index.bulk.delete'.tr(),
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ],
          onSelected: (value) => _handleMenuAction(value, profile),
        ),
      ),
    );
  }

  Widget _buildInfoBadge(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: const Color(0xFF64748B)),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
        ),
      ],
    );
  }

  Future<void> _handleMenuAction(String value, PrinterProfile profile) async {
    switch (value) {
      case 'edit':
        _startEditing(profile);
        break;
      case 'default':
        await ref
            .read(printerProfilesProvider.notifier)
            .setDefaultProfile(profile.id);
        break;
      case 'test_connection':
        await _testConnection(profile);
        break;
      case 'test':
        await _testPrint(profile);
        break;
      case 'duplicate':
        await _duplicateProfile(profile);
        break;
      case 'delete':
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AppDialog(
            title: 'app.delete_printer'.tr(),
            description: 'admin.confirmModal.defaults.message'.tr(),
            content: Text('app.are_you_sure_you_want_to_delet3'.tr()),
            secondaryLabel: 'admin.common.cancel'.tr(),
            onSecondary: () => Navigator.pop(context, false),
            primaryLabel: 'admin.common.delete'.tr(),
            primaryVariant: AppDialogPrimaryVariant.destructive,
            onPrimary: () => Navigator.pop(context, true),
          ),
        );
        if (confirm == true) {
          await ref
              .read(printerProfilesProvider.notifier)
              .removeProfile(profile.id);
        }
        break;
    }
  }

  Future<void> _duplicateProfile(PrinterProfile profile) async {
    final existing = ref.read(printerProfilesProvider).profiles;

    var candidate = 'app.printer_copy_of'.tr(namedArgs: {'name': profile.name});
    var suffix = 2;
    while (!PrinterValidators.isNameAvailable(candidate, existing)) {
      candidate =
          '${'app.printer_copy_of'.tr(namedArgs: {'name': profile.name})} $suffix';
      suffix++;
    }

    try {
      await ref
          .read(printerProfilesProvider.notifier)
          .addProfile(
            profile.copyWith(
              id: const Uuid().v4(),
              name: candidate,
              connectionParams: {...profile.connectionParams},
              capabilityParams: {...profile.capabilityParams},
            ),
          );
      if (!mounted) return;
      AppToasts.show(
        context,
        'app.printer_saved_successfully'.tr(),
        type: AppToastType.success,
      );
    } catch (e) {
      if (!mounted) return;
      AppToasts.show(
        context,
        'app.printer_save_failed'.tr(),
        description: e.toString(),
        type: AppToastType.error,
      );
    }
  }

  Widget _buildForm(Color accentColor) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildFormSection(
                    title: 'app.basic_information'.tr(),
                    icon: LucideIcons.info,
                    accentColor: accentColor,
                    children: [
                      FormInput(
                        label: 'app.profile_name'.tr(),
                        controller: _nameController,
                        hint: 'app.printer_name_hint'.tr(),
                        validator: _validateName,
                      ),
                      const SizedBox(height: 16),
                      FormSelect<PrinterTransport>(
                        label: 'app.transport_type'.tr(),
                        value: _transport,
                        items: PrinterTransport.values.map((t) {
                          return DropdownMenuItem(
                            value: t,
                            child: Text(_transportLabel(t)),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _transport = value);
                        },
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('app.printer_set_as_default'.tr()),
                        subtitle: Text(
                          'app.printer_set_as_default_hint'.tr(),
                          style: const TextStyle(fontSize: 12),
                        ),
                        value: _makeDefault,
                        activeThumbColor: accentColor,
                        onChanged: (v) => setState(() => _makeDefault = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildFormSection(
                    title: 'app.connection_details'.tr(),
                    icon: LucideIcons.radio,
                    accentColor: accentColor,
                    children: [
                      ..._buildConnectionFields(isMobile),
                      if (_supportsConnectionTest) ...[
                        const SizedBox(height: 16),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: AppButton.secondary(
                            label: 'app.printer_test_connection'.tr(),
                            icon: LucideIcons.plugZap,
                            loading: _isTestingConnection,
                            onPressed: _isTestingConnection
                                ? null
                                : _testConnectionFromForm,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildFormSection(
                    title: 'app.capabilities'.tr(),
                    icon: LucideIcons.settings,
                    accentColor: accentColor,
                    children: _buildCapabilityFields(isMobile, accentColor),
                  ),
                  const SizedBox(height: 32),
                  _buildFormActions(isMobile),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFormActions(bool isMobile) {
    final buttons = <Widget>[
      AppButton.secondary(
        label: 'admin.common.cancel'.tr(),
        onPressed: _cancelEditing,
        fullWidth: isMobile,
      ),
      AppButton.secondary(
        label: 'app.test_print'.tr(),
        icon: LucideIcons.printer,
        loading: _isTestPrinting,
        onPressed: _isTestPrinting ? null : _testPrintFromForm,
        fullWidth: isMobile,
      ),
      AppButton.primary(
        label: 'app.save_profile'.tr(),
        icon: LucideIcons.save,
        onPressed: _save,
        fullWidth: isMobile,
      ),
    ];

    if (isMobile) {
      // Primary action first so it stays within thumb reach.
      final ordered = buttons.reversed.toList();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < ordered.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            ordered[i],
          ],
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        for (var i = 0; i < buttons.length; i++) ...[
          if (i > 0) const SizedBox(width: 16),
          buttons[i],
        ],
      ],
    );
  }

  bool get _supportsConnectionTest =>
      _transport == PrinterTransport.network ||
      _transport == PrinterTransport.serial ||
      _transport == PrinterTransport.windows;

  List<Widget> _buildConnectionFields(bool isMobile) {
    switch (_transport) {
      case PrinterTransport.network:
        final host = FormInput(
          label: 'app.ip_address'.tr(),
          controller: _ipController,
          hint: '192.168.1.100',
          validator: _validateHost,
        );
        final port = FormInput(
          label: 'app.port'.tr(),
          controller: _portController,
          hint: '9100',
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          validator: _validatePort,
        );

        if (isMobile) {
          return [host, const SizedBox(height: 16), port];
        }
        return [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 2, child: host),
              const SizedBox(width: 16),
              Expanded(child: port),
            ],
          ),
        ];

      case PrinterTransport.bluetooth:
        return [
          FormInput(
            label: 'app.mac_address'.tr(),
            controller: _macController,
            hint: '00:11:22:33:44:55',
            suffixIcon: IconButton(
              icon: const Icon(LucideIcons.bluetoothSearching),
              onPressed: _showBondedDevicePicker,
              tooltip: 'app.printer_select_paired_device'.tr(),
            ),
            validator: _validateMac,
          ),
        ];

      case PrinterTransport.ble:
        return [
          FormInput(
            label: 'app.device_id_uuid'.tr(),
            controller: _deviceIdController,
            hint: 'XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX',
            suffixIcon: IconButton(
              icon: const Icon(LucideIcons.search),
              onPressed: _showBleScanDialog,
              tooltip: 'app.scan_for_ble_devices'.tr(),
            ),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'app.printer_device_id_required'.tr()
                : null,
          ),
        ];

      case PrinterTransport.windows:
        return [
          FormInput(
            label: 'app.printer_name'.tr(),
            controller: _printerNameController,
            hint: 'POS-58',
            suffixIcon: IconButton(
              icon: const Icon(LucideIcons.list),
              onPressed: _showSystemPrinterPicker,
              tooltip: 'app.printer_select_installed'.tr(),
            ),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'app.printer_windows_name_required'.tr()
                : null,
          ),
        ];

      case PrinterTransport.serial:
        final portField = FormInput(
          label: 'app.serial_port'.tr(),
          controller: _portNameController,
          hint: 'COM1 or /dev/ttyS0',
          suffixIcon: IconButton(
            icon: const Icon(LucideIcons.refreshCcw),
            onPressed: _showSerialPortPicker,
            tooltip: 'app.scan_for_ports'.tr(),
          ),
          validator: (v) => (v == null || v.trim().isEmpty)
              ? 'app.printer_serial_port_required'.tr()
              : null,
        );
        final baudField = FormSelect<int>(
          label: 'app.printer_baud_rate'.tr(),
          value: _baudRate,
          items: PrinterProfile.supportedBaudRates
              .map(
                (rate) =>
                    DropdownMenuItem(value: rate, child: Text('$rate')),
              )
              .toList(),
          onChanged: (v) {
            if (v == null) return;
            setState(() => _baudRate = v);
          },
        );

        if (isMobile) {
          return [portField, const SizedBox(height: 16), baudField];
        }
        return [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 2, child: portField),
              const SizedBox(width: 16),
              Expanded(child: baudField),
            ],
          ),
        ];

      case PrinterTransport.pdf:
        return [
          Text(
            'app.uses_system_default_print_dial'.tr(),
            style: const TextStyle(color: Colors.grey),
          ),
        ];
    }
  }

  List<Widget> _buildCapabilityFields(bool isMobile, Color accentColor) {
    final paperWidth = FormSelect<int>(
      label: 'app.paper_width'.tr(),
      value: _paperWidth,
      items: [
        DropdownMenuItem(value: 80, child: Text('app.80mm_standard'.tr())),
        DropdownMenuItem(value: 58, child: Text('app.58mm_narrow'.tr())),
      ],
      onChanged: (v) {
        if (v == null) return;
        setState(() => _paperWidth = v);
      },
    );

    final knownKeys = _capabilityProfiles.map((p) => p.key).toSet();
    final capabilityItems = [
      ..._capabilityProfiles.map(
        (p) => DropdownMenuItem(value: p.key, child: Text(p.displayName)),
      ),
      // Keep an unrecognised saved value selectable instead of silently
      // resetting the printer model.
      if (!knownKeys.contains(_capabilityProfile))
        DropdownMenuItem(
          value: _capabilityProfile,
          child: Text(_capabilityProfile),
        ),
    ];

    final model = FormSelect<String>(
      label: 'app.printer_model'.tr(),
      value: _capabilityProfile,
      items: capabilityItems,
      onChanged: (v) {
        if (v == null) return;
        setState(() => _capabilityProfile = v);
      },
    );

    final copies = FormSelect<int>(
      label: 'app.printer_copies'.tr(),
      value: _copies,
      items: [
        for (var i = 1; i <= PrinterProfile.maxCopies; i++)
          DropdownMenuItem(value: i, child: Text('$i')),
      ],
      onChanged: (v) {
        if (v == null) return;
        setState(() => _copies = v);
      },
    );

    final feedLines = FormSelect<int>(
      label: 'app.printer_feed_lines'.tr(),
      value: _feedLines,
      items: [
        for (var i = 0; i <= PrinterProfile.maxFeedLines; i++)
          DropdownMenuItem(value: i, child: Text('$i')),
      ],
      onChanged: (v) {
        if (v == null) return;
        setState(() => _feedLines = v);
      },
    );

    final toggles = <Widget>[
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        title: Text('app.auto_cut_paper'.tr()),
        value: _cut,
        onChanged: (v) => setState(() => _cut = v ?? false),
        activeColor: accentColor,
      ),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        title: Text('app.open_cash_drawer'.tr()),
        subtitle: Text('app.after_printing'.tr()),
        value: _drawer,
        onChanged: (v) => setState(() => _drawer = v ?? false),
        activeColor: accentColor,
      ),
    ];

    return [
      if (isMobile) ...[
        paperWidth,
        const SizedBox(height: 16),
        model,
        const SizedBox(height: 16),
        copies,
        const SizedBox(height: 16),
        feedLines,
      ] else ...[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: paperWidth),
            const SizedBox(width: 16),
            Expanded(child: model),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: copies),
            const SizedBox(width: 16),
            Expanded(child: feedLines),
          ],
        ),
      ],
      const SizedBox(height: 16),
      if (isMobile) ...[
        ...toggles,
      ] else ...[
        Row(
          children: [
            for (final toggle in toggles) Expanded(child: toggle),
          ],
        ),
        const SizedBox(height: 8),
      ],
      // Available on every platform: Arabic receipts need it on phones too.
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        title: Text('app.print_as_image_arabic_support'.tr()),
        subtitle: Text('app.rasterize_pdf_to_image_for_per'.tr()),
        value: _forceImagePrint,
        onChanged: (v) => setState(() => _forceImagePrint = v ?? false),
        activeColor: accentColor,
      ),
    ];
  }

  Widget _buildFormSection({
    required String title,
    required IconData icon,
    required Color accentColor,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: accentColor, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ...children,
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Validation
  // ---------------------------------------------------------------------------

  String? _validateName(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) return 'app.printer_name_required'.tr();

    final existing = ref.read(printerProfilesProvider).profiles;
    if (!PrinterValidators.isNameAvailable(
      name,
      existing,
      currentId: _editingProfile?.id,
    )) {
      return 'app.printer_name_taken'.tr();
    }
    return null;
  }

  String? _validateHost(String? value) {
    final host = value?.trim() ?? '';
    if (host.isEmpty) return 'app.printer_host_required'.tr();
    if (!PrinterValidators.isValidHost(host)) {
      return 'app.printer_host_invalid'.tr();
    }
    return null;
  }

  String? _validatePort(String? value) {
    final port = value?.trim() ?? '';
    if (port.isEmpty) return 'app.printer_port_invalid'.tr();
    if (!PrinterValidators.isValidPort(port)) {
      return 'app.printer_port_invalid'.tr();
    }
    return null;
  }

  String? _validateMac(String? value) {
    final mac = value?.trim() ?? '';
    if (mac.isEmpty) return 'app.printer_mac_required'.tr();
    if (!PrinterValidators.isValidMacAddress(mac)) {
      return 'app.printer_mac_invalid'.tr();
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Pickers
  // ---------------------------------------------------------------------------

  Future<void> _showSerialPortPicker() async {
    final ports = DiscoveryService.getAvailableSerialPorts();
    if (!mounted) return;
    if (ports.isEmpty) {
      AppToasts.show(context, 'app.no_serial_ports_found'.tr());
      return;
    }

    final selected = await _showPickerSheet(
      title: 'app.select_serial_port'.tr(),
      options: [
        for (final port in ports)
          _PickerOption(value: port, title: port, icon: LucideIcons.hardDrive),
      ],
    );

    if (selected != null) {
      setState(() => _portNameController.text = selected);
    }
  }

  Future<void> _showSystemPrinterPicker() async {
    final printers = await DiscoveryService.getSystemPrinters();
    if (!mounted) return;
    if (printers.isEmpty) {
      AppToasts.show(context, 'app.printer_no_installed_printers'.tr());
      return;
    }

    final selected = await _showPickerSheet(
      title: 'app.printer_select_installed'.tr(),
      options: [
        for (final printer in printers)
          _PickerOption(
            value: printer.name,
            title: printer.name,
            subtitle: [
              if (printer.model != null && printer.model!.isNotEmpty)
                printer.model!,
              if (printer.location != null && printer.location!.isNotEmpty)
                printer.location!,
            ].join(' · '),
            icon: LucideIcons.printer,
            enabled: printer.isAvailable,
          ),
      ],
    );

    if (selected != null) {
      setState(() => _printerNameController.text = selected);
    }
  }

  Future<void> _showBondedDevicePicker() async {
    final devices = await DiscoveryService.getBondedBluetoothDevices();
    if (!mounted) return;
    if (devices.isEmpty) {
      AppToasts.show(context, 'app.printer_no_paired_devices'.tr());
      return;
    }

    final selected = await _showPickerSheet(
      title: 'app.printer_select_paired_device'.tr(),
      options: [
        for (final device in devices)
          _PickerOption(
            value: device.address,
            title: device.name,
            subtitle: device.address,
            icon: LucideIcons.bluetooth,
          ),
      ],
    );

    if (selected != null) {
      setState(() => _macController.text = selected);
    }
  }

  Future<String?> _showPickerSheet({
    required String title,
    required List<_PickerOption> options,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final option in options)
                    ListTile(
                      enabled: option.enabled,
                      leading: Icon(option.icon),
                      title: Text(option.title),
                      subtitle:
                          option.subtitle == null || option.subtitle!.isEmpty
                          ? null
                          : Text(option.subtitle!),
                      onTap: () => Navigator.pop(context, option.value),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showBleScanDialog() async {
    final result = await showDialog<Object?>(
      context: context,
      builder: (context) => const _BleScanDialog(),
    );

    if (!mounted) return;
    if (result is ScanResult) {
      setState(() => _deviceIdController.text = result.device.remoteId.str);
    }
  }

  IconData _getIconForTransport(PrinterTransport transport) {
    switch (transport) {
      case PrinterTransport.network:
        return LucideIcons.network;
      case PrinterTransport.bluetooth:
        return LucideIcons.bluetooth;
      case PrinterTransport.ble:
        return LucideIcons.bluetooth;
      case PrinterTransport.windows:
        return LucideIcons.printer;
      case PrinterTransport.serial:
        return LucideIcons.hardDrive;
      case PrinterTransport.pdf:
        return LucideIcons.fileText;
    }
  }

  String _transportLabel(PrinterTransport transport) {
    switch (transport) {
      case PrinterTransport.network:
        return 'app.printer_transport_network'.tr();
      case PrinterTransport.bluetooth:
        return 'app.printer_transport_bluetooth'.tr();
      case PrinterTransport.ble:
        return 'app.printer_transport_ble'.tr();
      case PrinterTransport.windows:
        return 'app.printer_transport_windows'.tr();
      case PrinterTransport.serial:
        return 'app.printer_transport_serial'.tr();
      case PrinterTransport.pdf:
        return 'app.printer_transport_pdf'.tr();
    }
  }

  String _getConnectionSummary(PrinterProfile profile) {
    switch (profile.transport) {
      case PrinterTransport.network:
        return '${profile.ip ?? '—'}:${profile.port ?? 9100}';
      case PrinterTransport.bluetooth:
        return profile.macAddress ?? '—';
      case PrinterTransport.ble:
        return profile.deviceId ?? '—';
      case PrinterTransport.windows:
        return profile.printerName ?? '—';
      case PrinterTransport.serial:
        return '${profile.portName ?? '—'} · ${profile.baudRate ?? 9600} baud';
      case PrinterTransport.pdf:
        return 'app.uses_system_default_print_dial'.tr();
    }
  }

  String _getCapabilitySummary(PrinterProfile profile) {
    final parts = <String>[
      '${profile.paperWidth}mm',
      profile.capabilityProfileName,
      if (profile.copies > 1)
        'app.printer_copies_count'.tr(
          namedArgs: {'count': '${profile.copies}'},
        ),
      if (profile.cut) 'app.auto_cut_paper'.tr(),
      if (profile.drawer) 'app.open_cash_drawer'.tr(),
    ];
    return parts.join(' · ');
  }

  // ---------------------------------------------------------------------------
  // Tests
  // ---------------------------------------------------------------------------

  Future<void> _testConnectionFromForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isTestingConnection = true);
    try {
      await _testConnection(_buildProfileFromForm());
    } finally {
      if (mounted) setState(() => _isTestingConnection = false);
    }
  }

  Future<void> _testConnection(PrinterProfile profile) async {
    final result = await ref.read(printServiceProvider).testConnection(profile);
    if (!mounted) return;

    switch (result.outcome) {
      case PrinterTestOutcome.success:
        AppToasts.show(
          context,
          'app.printer_connection_ok'.tr(),
          type: AppToastType.success,
        );
        break;
      case PrinterTestOutcome.failure:
        AppToasts.show(
          context,
          'app.printer_connection_failed'.tr(),
          description: result.detail,
          type: AppToastType.error,
        );
        break;
      case PrinterTestOutcome.unsupported:
        AppToasts.show(
          context,
          'app.printer_connection_test_unsupported'.tr(),
          type: AppToastType.warning,
        );
        break;
    }
  }

  Future<void> _testPrintFromForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isTestPrinting = true);
    try {
      await _testPrint(_buildProfileFromForm());
    } finally {
      if (mounted) setState(() => _isTestPrinting = false);
    }
  }

  Future<void> _testPrint(PrinterProfile profile) async {
    try {
      final items = [
        CartItem(
          productId: 'test-1',
          name: 'Test Product 1',
          quantity: 1,
          price: 10.0,
        ),
        CartItem(
          productId: 'test-2',
          name: 'Test Product 2',
          quantity: 2,
          price: 7.5,
        ),
      ];

      await ref
          .read(printServiceProvider)
          .printReceipt(
            profile: profile,
            items: items,
            total: 25.0,
            layout: ref.read(printerProfilesProvider).receiptLayout,
          );

      if (mounted) {
        AppToasts.show(
          context,
          'app.test_print_sent'.tr(),
          type: AppToastType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        AppToasts.show(
          context,
          'app.printer_test_print_failed'.tr(),
          description: e.toString(),
          type: AppToastType.error,
        );
      }
    }
  }
}

class _PickerOption {
  final String value;
  final String title;
  final String? subtitle;
  final IconData icon;
  final bool enabled;

  const _PickerOption({
    required this.value,
    required this.title,
    required this.icon,
    this.subtitle,
    this.enabled = true,
  });
}

class _BleScanDialog extends StatefulWidget {
  const _BleScanDialog();

  @override
  State<_BleScanDialog> createState() => _BleScanDialogState();
}

class _BleScanDialogState extends State<_BleScanDialog> {
  final List<ScanResult> _results = [];
  bool _isScanning = true;

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  void _startScan() {
    setState(() {
      _results.clear();
      _isScanning = true;
    });

    DiscoveryService.scanBleDevices().listen((results) {
      if (mounted) {
        setState(() {
          _results.clear(); // FlutterBluePlus returns snapshot of all results
          _results.addAll(results);
        });
      }
    });

    // Auto stop after 5s (can also be handled by the service timeout)
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    });
  }

  @override
  void dispose() {
    DiscoveryService.stopBleScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: 'app.scanning_ble_devices'.tr(),
      description: _isScanning
          ? 'app.printer_scanning'.tr()
          : 'app.printer_select_device_from_list'.tr(),
      maxWidth: 720,
      content: SizedBox(
        height: 320,
        child: _results.isEmpty
            ? Center(
                child: _isScanning
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text('app.no_devices_found'.tr()),
              )
            : ListView.builder(
                itemCount: _results.length,
                itemBuilder: (context, index) {
                  final result = _results[index];
                  final name = result.device.platformName.isNotEmpty
                      ? result.device.platformName
                      : 'app.printer_unknown_device'.tr();
                  return ListTile(
                    title: Text(name),
                    subtitle: Text(result.device.remoteId.str),
                    trailing: Text('${result.rssi} dBm'),
                    onTap: () => Navigator.pop(context, result),
                  );
                },
              ),
      ),
      secondaryLabel: 'admin.common.cancel'.tr(),
      onSecondary: () => Navigator.pop(context),
      primaryLabel: _isScanning ? null : 'app.printer_scan_again'.tr(),
      onPrimary: _isScanning ? null : _startScan,
    );
  }
}
