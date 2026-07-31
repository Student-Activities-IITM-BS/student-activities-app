import 'package:flutter_test/flutter_test.dart';
import 'package:student_activities/models/models.dart';

void main() {
  test('event update accepts the backend payload shape', () {
    final update = EventUpdate.fromJson({
      'id': 'update-1',
      'title': 'Workshop',
      'content': 'Build a mobile client.',
      'image_urls': ['https://example.test/poster.png'],
      'author_name': 'Student Activities',
      'author_email': 'team@study.iitm.ac.in',
      'likes_count': 12,
      'dislikes_count': 1,
      'created_at': '2026-07-29T10:00:00.000Z',
    });

    expect(update.id, 'update-1');
    expect(update.imageUrls, ['https://example.test/poster.png']);
    expect(update.likesCount, 12);
  });

  test('calendar event accepts the authenticated calendar contract', () {
    final event = CalendarEvent.fromJson({
      'id': 'event-1',
      'title': 'Town hall',
      'description': 'Open student discussion',
      'start_time': '2026-07-30T12:00:00.000Z',
      'end_time': '2026-07-30T13:00:00.000Z',
      'organizer_name': 'SEC',
      'organizer_email': 'sec@study.iitm.ac.in',
      'category': 'PARADOX',
      'status': 'UPCOMING',
      'form_link': 'https://example.test/register',
    });

    expect(event.category, 'PARADOX');
    expect(event.formLink, 'https://example.test/register');
    expect(event.endTime.isAfter(event.startTime), isTrue);
  });
}
