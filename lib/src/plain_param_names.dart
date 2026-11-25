import 'models/adshift_event_param.dart';

const _irregularConstants = {
  AdshiftEventParam.latitude: 'latitude',
  AdshiftEventParam.longitude: 'longitude',
  AdshiftEventParam.classValue: 'classValue',
};

String _camelCase(String snakeCase) => snakeCase.replaceAllMapped(
  RegExp('_([a-z0-9])'),
  (match) => match[1]!.toUpperCase(),
);

/// The name of the [AdshiftEventParam] constant that holds [wireName].
String eventParamConstant(String wireName) =>
    _irregularConstants[wireName] ??
    _camelCase(
      wireName.substring('as_'.length).replaceFirst('adrev_', 'ad_revenue_'),
    );

/// Plain spellings a caller is likely to use instead of a standard parameter
/// (`price`, `content_id`, `contentId`), each with the standard name it means.
final Map<String, String> plainParamNames = () {
  final standard = AdshiftEventParam.all.toSet();
  final plain = <String, String>{};
  for (final wireName in AdshiftEventParam.all) {
    final bare = wireName.substring('as_'.length);
    for (final alias in [
      bare,
      _camelCase(bare),
      eventParamConstant(wireName),
    ]) {
      if (!standard.contains(alias)) plain.putIfAbsent(alias, () => wireName);
    }
  }
  return plain;
}();
