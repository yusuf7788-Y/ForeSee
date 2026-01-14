import 'package:flutter/material.dart';
import 'package:device_calendar/device_calendar.dart';
import 'package:intl/intl.dart';
import '../services/calendar_service.dart';
import 'grey_notification.dart';

class AddToCalendarPanel extends StatefulWidget {
  final String title;
  final DateTime startTime;
  final DateTime endTime;
  final CalendarService calendarService;

  const AddToCalendarPanel({
    super.key,
    required this.title,
    required this.startTime,
    required this.endTime,
    required this.calendarService,
  });

  @override
  State<AddToCalendarPanel> createState() => _AddToCalendarPanelState();
}

class _AddToCalendarPanelState extends State<AddToCalendarPanel> {
  List<Calendar> _calendars = [];
  String? _selectedCalendarId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCalendars();
  }

  Future<void> _loadCalendars() async {
    final calendars = await widget.calendarService.getCalendars();
    setState(() {
      _calendars = calendars.where((c) => c.isReadOnly == false).toList();
      if (_calendars.isNotEmpty) {
        _selectedCalendarId = _calendars.first.id;
      }
      _isLoading = false;
    });
  }

  Future<void> _addEvent() async {
    if (_selectedCalendarId == null) return;

    final eventId = await widget.calendarService.addEvent(
      calendarId: _selectedCalendarId!,
      title: widget.title,
      startTime: widget.startTime,
      endTime: widget.endTime,
    );

    if (mounted) {
      if (eventId != null) {
        GreyNotification.show(context, 'Etkinlik takvime eklendi!');
      } else {
        GreyNotification.show(context, 'Etkinlik eklenemedi.');
      }
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Takvime Ekle', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Text('Başlık: ${widget.title}'),
          const SizedBox(height: 8),
          Text('Başlangıç: ${DateFormat('dd MMM yyyy, HH:mm').format(widget.startTime)}'),
          const SizedBox(height: 8),
          Text('Bitiş: ${DateFormat('dd MMM yyyy, HH:mm').format(widget.endTime)}'),
          const SizedBox(height: 16),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_calendars.isEmpty)
            const Text('Yazılabilir takvim bulunamadı.')
          else
            DropdownButton<String>(
              value: _selectedCalendarId,
              isExpanded: true,
              items: _calendars.map((calendar) {
                return DropdownMenuItem(
                  value: calendar.id,
                  child: Text(calendar.name ?? 'İsimsiz Takvim'),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedCalendarId = value;
                });
              },
            ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _selectedCalendarId != null ? _addEvent : null,
            child: const Text('Ekle'),
          ),
        ],
      ),
    );
  }
}
