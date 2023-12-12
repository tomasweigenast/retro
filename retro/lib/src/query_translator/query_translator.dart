import 'package:retro/retro.dart';

abstract interface class QueryTranslator<In, Out> {
  Out translate(In data, Filter filter);
}
