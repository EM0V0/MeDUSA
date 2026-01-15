/// Message entity for doctor-patient communication
/// Supports secure messaging between medical professionals and patients
class Message {
  final String id;
  final String senderId;
  final String senderName;
  final String senderRole;
  final String receiverId;
  final String receiverName;
  final String receiverRole;
  final String content;
  final MessageType type;
  final MessagePriority priority;
  final DateTime timestamp;
  final bool isRead;
  final List<MessageAttachment> attachments;
  final String? replyToMessageId;

  const Message({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    required this.receiverId,
    required this.receiverName,
    required this.receiverRole,
    required this.content,
    required this.type,
    required this.priority,
    required this.timestamp,
    this.isRead = false,
    this.attachments = const [],
    this.replyToMessageId,
  });

  /// Create a copy of this message with updated fields
  Message copyWith({
    String? id,
    String? senderId,
    String? senderName,
    String? senderRole,
    String? receiverId,
    String? receiverName,
    String? receiverRole,
    String? content,
    MessageType? type,
    MessagePriority? priority,
    DateTime? timestamp,
    bool? isRead,
    List<MessageAttachment>? attachments,
    String? replyToMessageId,
  }) {
    return Message(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderRole: senderRole ?? this.senderRole,
      receiverId: receiverId ?? this.receiverId,
      receiverName: receiverName ?? this.receiverName,
      receiverRole: receiverRole ?? this.receiverRole,
      content: content ?? this.content,
      type: type ?? this.type,
      priority: priority ?? this.priority,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      attachments: attachments ?? this.attachments,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
    );
  }

  /// Convert message to JSON for storage/transmission
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'senderId': senderId,
      'senderName': senderName,
      'senderRole': senderRole,
      'receiverId': receiverId,
      'receiverName': receiverName,
      'receiverRole': receiverRole,
      'content': content,
      'type': type.value,
      'priority': priority.value,
      'timestamp': timestamp.toIso8601String(),
      'isRead': isRead,
      'attachments': attachments.map((a) => a.toJson()).toList(),
      'replyToMessageId': replyToMessageId,
    };
  }

  /// Create message from JSON
  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] ?? '',
      senderId: json['senderId'] ?? '',
      senderName: json['senderName'] ?? '',
      senderRole: json['senderRole'] ?? '',
      receiverId: json['receiverId'] ?? '',
      receiverName: json['receiverName'] ?? '',
      receiverRole: json['receiverRole'] ?? '',
      content: json['content'] ?? '',
      type: MessageType.fromString(json['type'] ?? 'text'),
      priority: MessagePriority.fromString(json['priority'] ?? 'normal'),
      timestamp: DateTime.parse(json['timestamp']),
      isRead: json['isRead'] ?? false,
      attachments: (json['attachments'] as List<dynamic>?)
          ?.map((a) => MessageAttachment.fromJson(a))
          .toList() ?? [],
      replyToMessageId: json['replyToMessageId'],
    );
  }

  /// Check if message is from a medical professional
  bool get isFromMedicalProfessional => senderRole == 'doctor' || senderRole == 'admin';

  /// Check if message is urgent
  bool get isUrgent => priority == MessagePriority.urgent;

  /// Get formatted timestamp
  String get formattedTimestamp {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }
}

/// Message types enumeration
enum MessageType {
  text('text', 'Text Message'),
  image('image', 'Image'),
  document('document', 'Document'),
  medicalReport('medical_report', 'Medical Report'),
  appointment('appointment', 'Appointment'),
  prescription('prescription', 'Prescription'),
  reminder('reminder', 'Reminder');

  const MessageType(this.value, this.displayName);

  final String value;
  final String displayName;

  static MessageType fromString(String value) {
    for (MessageType type in MessageType.values) {
      if (type.value == value) {
        return type;
      }
    }
    return MessageType.text;
  }
}

/// Message priority enumeration
enum MessagePriority {
  low('low', 'Low Priority'),
  normal('normal', 'Normal'),
  high('high', 'High Priority'),
  urgent('urgent', 'Urgent');

  const MessagePriority(this.value, this.displayName);

  final String value;
  final String displayName;

  static MessagePriority fromString(String value) {
    for (MessagePriority priority in MessagePriority.values) {
      if (priority.value == value) {
        return priority;
      }
    }
    return MessagePriority.normal;
  }
}

/// Message attachment entity
class MessageAttachment {
  final String id;
  final String fileName;
  final String fileType;
  final int fileSize;
  final String? thumbnailUrl;
  final String downloadUrl;

  const MessageAttachment({
    required this.id,
    required this.fileName,
    required this.fileType,
    required this.fileSize,
    this.thumbnailUrl,
    required this.downloadUrl,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fileName': fileName,
      'fileType': fileType,
      'fileSize': fileSize,
      'thumbnailUrl': thumbnailUrl,
      'downloadUrl': downloadUrl,
    };
  }

  factory MessageAttachment.fromJson(Map<String, dynamic> json) {
    return MessageAttachment(
      id: json['id'] ?? '',
      fileName: json['fileName'] ?? '',
      fileType: json['fileType'] ?? '',
      fileSize: json['fileSize'] ?? 0,
      thumbnailUrl: json['thumbnailUrl'],
      downloadUrl: json['downloadUrl'] ?? '',
    );
  }

  /// Get file size in human readable format
  String get formattedFileSize {
    if (fileSize < 1024) {
      return '${fileSize}B';
    } else if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)}KB';
    } else {
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)}MB';
    }
  }

  /// Check if file is an image
  bool get isImage => fileType.startsWith('image/');

  /// Check if file is a document
  bool get isDocument => fileType.contains('pdf') || 
                        fileType.contains('doc') || 
                        fileType.contains('text');
}

/// Conversation entity for grouping messages between two users
class Conversation {
  final String id;
  final String participantOneId;
  final String participantOneName;
  final String participantOneRole;
  final String participantTwoId;
  final String participantTwoName;
  final String participantTwoRole;
  final Message? lastMessage;
  final int unreadCount;
  final DateTime lastActivity;

  const Conversation({
    required this.id,
    required this.participantOneId,
    required this.participantOneName,
    required this.participantOneRole,
    required this.participantTwoId,
    required this.participantTwoName,
    required this.participantTwoRole,
    this.lastMessage,
    this.unreadCount = 0,
    required this.lastActivity,
  });

  /// Get the other participant's name for current user
  String getOtherParticipantName(String currentUserId) {
    return currentUserId == participantOneId ? participantTwoName : participantOneName;
  }

  /// Get the other participant's role for current user
  String getOtherParticipantRole(String currentUserId) {
    return currentUserId == participantOneId ? participantTwoRole : participantOneRole;
  }

  /// Get the other participant's ID for current user
  String getOtherParticipantId(String currentUserId) {
    return currentUserId == participantOneId ? participantTwoId : participantOneId;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'participantOneId': participantOneId,
      'participantOneName': participantOneName,
      'participantOneRole': participantOneRole,
      'participantTwoId': participantTwoId,
      'participantTwoName': participantTwoName,
      'participantTwoRole': participantTwoRole,
      'lastMessage': lastMessage?.toJson(),
      'unreadCount': unreadCount,
      'lastActivity': lastActivity.toIso8601String(),
    };
  }

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'] ?? '',
      participantOneId: json['participantOneId'] ?? '',
      participantOneName: json['participantOneName'] ?? '',
      participantOneRole: json['participantOneRole'] ?? '',
      participantTwoId: json['participantTwoId'] ?? '',
      participantTwoName: json['participantTwoName'] ?? '',
      participantTwoRole: json['participantTwoRole'] ?? '',
      lastMessage: json['lastMessage'] != null 
          ? Message.fromJson(json['lastMessage']) 
          : null,
      unreadCount: json['unreadCount'] ?? 0,
      lastActivity: DateTime.parse(json['lastActivity']),
    );
  }
}

