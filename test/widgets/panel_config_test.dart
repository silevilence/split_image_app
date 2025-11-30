import 'package:flutter_test/flutter_test.dart';
import 'package:split_image_app/models/app_config.dart';

void main() {
  group('PanelConfig', () {
    test('should create with default values', () {
      final config = PanelConfig();

      expect(config.settingsSplitRatio, 0.4);
      expect(PanelConfig.minSettingsHeight, 200);
      expect(PanelConfig.minPreviewHeight, 200);
    });

    test('should create from map', () {
      final map = {'settings_split_ratio': 0.6};

      final config = PanelConfig.fromMap(map);

      expect(config.settingsSplitRatio, 0.6);
    });

    test('should handle missing values in fromMap', () {
      final map = <String, dynamic>{};

      final config = PanelConfig.fromMap(map);

      expect(config.settingsSplitRatio, 0.4); // 默认值
    });

    test('should convert to map', () {
      final config = PanelConfig(settingsSplitRatio: 0.5);

      final map = config.toMap();

      expect(map['settings_split_ratio'], 0.5);
    });

    test('should handle integer values in fromMap', () {
      final map = {
        'settings_split_ratio': 1, // 整数
      };

      final config = PanelConfig.fromMap(map);

      expect(config.settingsSplitRatio, 1.0);
    });
  });

  group('AppConfig with PanelConfig', () {
    test('should include panel config with defaults', () {
      final config = AppConfig.defaults();

      expect(config.panel.settingsSplitRatio, 0.4);
    });

    test('should parse panel config from map', () {
      final map = {
        'export': {'default_prefix': 'test', 'default_format': 'png'},
        'shortcuts': {
          'toggle_mode': 'V',
          'delete_line': 'Delete',
          'undo': 'Ctrl+Z',
          'redo': 'Ctrl+Y',
        },
        'grid': {
          'default_rows': 4,
          'default_cols': 4,
          'default_algorithm': 'fixedEvenSplit',
        },
        'panel': {'settings_split_ratio': 0.35},
      };

      final config = AppConfig.fromMap(map);

      expect(config.panel.settingsSplitRatio, 0.35);
    });

    test('should include panel config in toMap', () {
      final config = AppConfig(panel: PanelConfig(settingsSplitRatio: 0.45));

      final map = config.toMap();

      expect(map.containsKey('panel'), true);
      expect(map['panel']['settings_split_ratio'], 0.45);
    });

    test('should handle missing panel config in fromMap', () {
      final map = {'export': {}, 'shortcuts': {}, 'grid': {}};

      final config = AppConfig.fromMap(map);

      expect(config.panel.settingsSplitRatio, 0.4); // 默认值
    });
  });
}
