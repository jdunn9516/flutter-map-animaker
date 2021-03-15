// Port of SphericalUtil from android-maps-utils (https://github.com/googlemaps/android-maps-utils)
// https://docs.microsoft.com/en-us/bingmaps/articles/bing-maps-tile-system?redirectedfrom=MSDN
import 'package:flutter_animarker/core/i_lat_lng.dart';
import 'package:flutter_animarker/models/lat_lng_info.dart';
import 'dart:math' as math;
import 'math_util.dart';

class SphericalUtil {
  static const double earthRadius = 6378137.0;
  static const double maxLatitude = 85.05112878;
  static const double minLatitude = -85.05112878;

  static num computeHeading(ILatLng from, ILatLng to) {
    final fromLat = MathUtil.toRadians(from.latitude);
    final fromLng = MathUtil.toRadians(from.longitude);
    final toLat = MathUtil.toRadians(to.latitude);
    final toLng = MathUtil.toRadians(to.longitude);
    final dLng = toLng - fromLng;
    var x = math.sin(dLng) * math.cos(toLat);
    var y = math.cos(fromLat) * math.sin(toLat) - math.sin(fromLat) * math.cos(toLat) * math.cos(dLng);
    final heading = math.atan2(x, y);

    return MathUtil.toDegrees(heading);
    //return MathUtil.wrap(MathUtil.toDegrees(heading), -180, 180);
  }

  static double calculateZoomScale(double densityDpi, double zoomLevel, ILatLng target){

    var dpi = densityDpi * 160;

    double mapwidth = 256.0 * math.pow(2, zoomLevel);
    double clipLatitude = math.min(math.max(target.latitude, minLatitude), maxLatitude);
    double angle = clipLatitude * math.pi/180;
    double angleRadians = MathUtil.toRadians(angle).toDouble();
    double groundResolution = (math.cos(angleRadians) * 2 * math.pi * SphericalUtil.earthRadius) / mapwidth;
    double mapScale = (groundResolution * dpi / 0.0254);

    return 1/mapScale;
  }

  static double getBearing(ILatLng begin, ILatLng end) {
    double lat = (begin.latitude - end.latitude).abs();
    double lng = (begin.longitude - end.longitude).abs();

    if (begin.latitude < end.latitude && begin.longitude < end.longitude) {
      return MathUtil.toDegrees(math.atan(lng / lat)) as double /*+ 90*/;
    } else if (begin.latitude >= end.latitude && begin.longitude < end.longitude) {
      return ((90 - MathUtil.toDegrees(math.atan(lng / lat))) + 90) /*+ 45*/;
    } else if (begin.latitude >= end.latitude && begin.longitude >= end.longitude) {
      return (MathUtil.toDegrees(math.atan(lng / lat)) + 180) /*- 90*/;
    } else if (begin.latitude < end.latitude && begin.longitude >= end.longitude) {
      return ((90 - MathUtil.toDegrees(math.atan(lng / lat))) + 270) /*+ 90*/;
    }

    return -1;
  }

  /// Returns the LatLng which lies the given fraction of the way between the
  /// origin LatLng and the destination LatLng.
  /// @param from     The LatLng from which to start.
  /// @param to       The LatLng toward which to travel.
  /// @param fraction A fraction of the distance to travel.
  /// @return The interpolated LatLng.
  static ILatLng interpolate(ILatLng from, ILatLng to, num fraction) {
    if (from.isEmpty) return to;

    final fromLat = MathUtil.toRadians(from.latitude);
    final fromLng = MathUtil.toRadians(from.longitude);
    final toLat = MathUtil.toRadians(to.latitude);
    final toLng = MathUtil.toRadians(to.longitude);
    final cosFromLat = math.cos(fromLat);
    final cosToLat = math.cos(toLat);

    // Computes Spherical interpolation coefficients.
    final angle = computeAngleBetween(from, to);
    final sinAngle = math.sin(angle);

    if (sinAngle < 1E-6) {
      return LatLngInfo(from.latitude + fraction * (to.latitude - from.latitude),
          from.longitude + fraction * (to.longitude - from.longitude), from.markerId);
    }

    final a = math.sin((1 - fraction) * angle) / sinAngle;
    final b = math.sin(fraction * angle) / sinAngle;

    // Converts from polar to vector and interpolate.
    final x = a * cosFromLat * math.cos(fromLng) + b * cosToLat * math.cos(toLng);
    final y = a * cosFromLat * math.sin(fromLng) + b * cosToLat * math.sin(toLng);
    final z = a * math.sin(fromLat) + b * math.sin(toLat);

    // Converts interpolated vector back to polar.
    final lat = math.atan2(z, math.sqrt(x * x + y * y));
    final lng = math.atan2(y, x);

    return LatLngInfo(
        MathUtil.toDegrees(lat).toDouble(), MathUtil.toDegrees(lng).toDouble(), from.markerId);
  }

  static num distanceRadians(num lat1, num lng1, num lat2, num lng2) =>
      MathUtil.arcHav(MathUtil.havDistance(lat1, lat2, lng1 - lng2));

  static num computeAngleBetween(ILatLng from, ILatLng to) => distanceRadians(
      MathUtil.toRadians(from.latitude),
      MathUtil.toRadians(from.longitude),
      MathUtil.toRadians(to.latitude),
      MathUtil.toRadians(to.longitude));

  static double angleLerp(double from, double to, double t) {
    double shortestAngle = angleShortestDistance(from, to);

    double result = from * (1 - t) + shortestAngle * t;

    //1e-6: the smallest value that is not stringified in scientific notation.
    //Prevent unwanted result [1e-6, -1e-6]
    if (result < 1e-6 && result > -1e-6) return 0;

    return result;
  }

/*  function interpolator(t) {
    return a * (1 - t) + b * t;
  }*/

/*  static double angleShortestDistance(double from, double to) {
    var max = math.pi * 2;
    var delta = to - from;
    var da = delta.sign * (delta.abs() % max);
    return delta.sign * (2 * da.abs() % max) - da;
  }*/

  static double angleShortestDistance(double from, double to) {
    return ((to - from) + 180) % 360 - 180;
  }

  static num computeDistanceBetween(ILatLng from, ILatLng to) =>
      computeAngleBetween(from, to) * earthRadius;

  static double bearingBetweenLocations(LatLngInfo latLngFrom, LatLngInfo latLngTo) {
    double lat1 = latLngTo.latitude * math.pi / 180;
    double long1 = latLngTo.longitude * math.pi / 180;
    double lat2 = latLngFrom.latitude * math.pi / 180;
    double long2 = latLngFrom.longitude * math.pi / 180;

    double dLon = (long2 - long1);

    double y = math.sin(dLon) * math.cos(lat2);
    double x = math.cos(lat1) * math.sin(lat2) - math.sin(lat1) * math.cos(lat2) * math.cos(dLon);

    double brng = math.atan2(y, x);

    brng = MathUtil.toDegrees(brng) as double;
    brng = (brng + 360) % 360;

    return brng;
  }

  static double latRad(lat) {
    var sin = math.sin(lat * math.pi / 180);
    var radX2 = math.log((1 + sin) / (1 - sin)) / 2;
    return math.max(math.min(radX2, math.pi), -math.pi) / 2;
  }

  static double zoom(mapPx, worldPx, fraction) {
    return math.log(mapPx / worldPx / fraction) / math.ln2;
  }

  /*static double getBoundsZoomLevel(LatLngBounds bounds, Size size, [double ratio = 1, double padding = 0]) {
    var worldDim = {
      'height': 256 * ratio,
      'width': 256 * ratio,
    };
    var zooMax = 21.0;

    var ne = bounds.northeast;
    var sw = bounds.southwest;

    var latFraction = (latRad(ne.latitude) - latRad(sw.latitude)) / math.pi;

    var lngDiff = ne.longitude - sw.longitude;
    var lngFraction = ((lngDiff < 0) ? (lngDiff + 360) : lngDiff) / 360;

    var latZoom = zoom((size.height * ratio) - (padding * ratio),
        worldDim["height"], latFraction);

    var lngZoom = zoom((size.width * ratio) - (padding * ratio),
        worldDim["width"], lngFraction);

    return math.min(math.min(latZoom, lngZoom), zooMax);
  }*/
}
