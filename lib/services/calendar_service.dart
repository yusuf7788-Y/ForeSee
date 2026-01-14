import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/services.dart';
import 'package:timezone/timezone.dart' as tz;

class CalendarService {
  final DeviceCalendarPlugin _deviceCalendarPlugin = DeviceCalendarPlugin();

  Future<bool> requestPermissions() async {
    var permissionsGranted = await _deviceCalendarPlugin.hasPermissions();
    if (permissionsGranted.isSuccess && !permissionsGranted.data!) {
      permissionsGranted = await _deviceCalendarPlugin.requestPermissions();
      return permissionsGranted.isSuccess && permissionsGranted.data!;
    }
    return permissionsGranted.data ?? false;
  }

  Future<List<Calendar>> getCalendars() async {
    final hasPerms = await requestPermissions();
    if (!hasPerms) return [];

    final calendarsResult = await _deviceCalendarPlugin.retrieveCalendars();
    return calendarsResult.data ?? [];
  }

  Future<String?> addEvent({
    required String calendarId,
    required String title,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    final hasPerms = await requestPermissions();
    if (!hasPerms) return null;

    final event = Event(
      calendarId,
      title: title,
      start: tz.TZDateTime.from(startTime, tz.local),
      end: tz.TZDateTime.from(endTime, tz.local),
    );

    final createEventResult = await _deviceCalendarPlugin.createOrUpdateEvent(event);
    return createEventResult?.data;
  }
}
