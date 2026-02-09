class EventDetailsModel {
  final String title;
  final String mode; // 'Online' or 'Offline'
  final String code;
  final String description;
  final String dateTime;
  final String action; // 'OPEN', 'CLOSE', 'OFFLINE_UNLOCK', etc.

  EventDetailsModel({
    required this.title,
    required this.mode,
    required this.code,
    required this.description,
    required this.dateTime,
    required this.action,
  });
}
