import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:responsive_framework/responsive_framework.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/font_utils.dart';
import '../../../../core/utils/icon_utils.dart';
import '../../../../shared/services/role_service.dart';
import '../../domain/entities/message.dart';

/// Messages page for doctor-patient communication
/// Provides secure messaging interface for medical professionals and patients
class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  final RoleService _roleService = RoleService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  
  // Demo conversations data
  List<Conversation> _conversations = [];

  @override
  void initState() {
    super.initState();
    _loadDemoConversations();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadDemoConversations() {
    final currentUser = _roleService.currentUser;
    if (currentUser == null) return;

    final now = DateTime.now();
    
    if (_roleService.isDoctor) {
      // Doctor sees conversations with patients
      _conversations = [
        Conversation(
          id: 'conv_1',
          participantOneId: currentUser.id,
          participantOneName: currentUser.name,
          participantOneRole: 'doctor',
          participantTwoId: 'patient_1',
          participantTwoName: 'John Doe',
          participantTwoRole: 'patient',
          lastMessage: Message(
            id: 'msg_1',
            senderId: 'patient_1',
            senderName: 'John Doe',
            senderRole: 'patient',
            receiverId: currentUser.id,
            receiverName: currentUser.name,
            receiverRole: 'doctor',
            content: 'My tremor symptoms have been worse today. Should I be concerned?',
            type: MessageType.text,
            priority: MessagePriority.high,
            timestamp: now.subtract(const Duration(minutes: 15)),
            isRead: false,
          ),
          unreadCount: 2,
          lastActivity: now.subtract(const Duration(minutes: 15)),
        ),
        Conversation(
          id: 'conv_2',
          participantOneId: currentUser.id,
          participantOneName: currentUser.name,
          participantOneRole: 'doctor',
          participantTwoId: 'patient_2',
          participantTwoName: 'Jane Smith',
          participantTwoRole: 'patient',
          lastMessage: Message(
            id: 'msg_2',
            senderId: currentUser.id,
            senderName: currentUser.name,
            senderRole: 'doctor',
            receiverId: 'patient_2',
            receiverName: 'Jane Smith',
            receiverRole: 'patient',
            content: 'Your latest test results look good. Continue with current medication.',
            type: MessageType.text,
            priority: MessagePriority.normal,
            timestamp: now.subtract(const Duration(hours: 2)),
            isRead: true,
          ),
          unreadCount: 0,
          lastActivity: now.subtract(const Duration(hours: 2)),
        ),
        Conversation(
          id: 'conv_3',
          participantOneId: currentUser.id,
          participantOneName: currentUser.name,
          participantOneRole: 'doctor',
          participantTwoId: 'patient_3',
          participantTwoName: 'Robert Chen',
          participantTwoRole: 'patient',
          lastMessage: Message(
            id: 'msg_3',
            senderId: 'patient_3',
            senderName: 'Robert Chen',
            senderRole: 'patient',
            receiverId: currentUser.id,
            receiverName: currentUser.name,
            receiverRole: 'doctor',
            content: 'Thank you for adjusting my medication. I\'m feeling much better.',
            type: MessageType.text,
            priority: MessagePriority.normal,
            timestamp: now.subtract(const Duration(days: 1)),
            isRead: true,
          ),
          unreadCount: 0,
          lastActivity: now.subtract(const Duration(days: 1)),
        ),
      ];
    } else if (_roleService.isPatient) {
      // Patient sees conversation with their doctor
      _conversations = [
        Conversation(
          id: 'conv_patient_1',
          participantOneId: currentUser.id,
          participantOneName: currentUser.name,
          participantOneRole: 'patient',
          participantTwoId: 'doctor_1',
          participantTwoName: 'Dr. Sarah Wilson',
          participantTwoRole: 'doctor',
          lastMessage: Message(
            id: 'msg_patient_1',
            senderId: 'doctor_1',
            senderName: 'Dr. Sarah Wilson',
            senderRole: 'doctor',
            receiverId: currentUser.id,
            receiverName: currentUser.name,
            receiverRole: 'patient',
            content: 'I\'ve reviewed your recent sensor data. Let\'s schedule a follow-up appointment to discuss your progress.',
            type: MessageType.text,
            priority: MessagePriority.normal,
            timestamp: now.subtract(const Duration(minutes: 30)),
            isRead: false,
          ),
          unreadCount: 1,
          lastActivity: now.subtract(const Duration(minutes: 30)),
        ),
      ];
    }

    setState(() {});
  }

  List<Conversation> get _filteredConversations {
    if (_searchQuery.isEmpty) {
      return _conversations;
    }
    return _conversations.where((conversation) {
      final otherParticipantName = conversation.getOtherParticipantName(
        _roleService.currentUser?.id ?? ''
      ).toLowerCase();
      final lastMessageContent = conversation.lastMessage?.content.toLowerCase() ?? '';
      final query = _searchQuery.toLowerCase();
      
      return otherParticipantName.contains(query) || 
             lastMessageContent.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveBreakpoints.of(context).smallerThan(TABLET);

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: Column(
        children: [
          _buildHeader(isMobile),
          Expanded(
            child: _conversations.isEmpty 
                ? _buildEmptyState()
                : _buildConversationsList(isMobile),
          ),
        ],
      ),
      floatingActionButton: _roleService.isDoctor
          ? FloatingActionButton(
              onPressed: _showNewMessageDialog,
              backgroundColor: AppColors.primary,
              child: const Icon(
                Icons.add_comment,
                color: AppColors.onPrimary,
              ),
            )
          : null,
    );
  }

  Widget _buildHeader(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: AppColors.lightDivider, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.message,
                color: AppColors.primary,
                size: IconUtils.getResponsiveIconSize(IconSizeType.large, context),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  _roleService.isDoctor 
                      ? 'Patient Messages' 
                      : 'Messages with Your Doctor',
                  style: FontUtils.title(
                    context: context,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
              if (_conversations.isNotEmpty) ...[
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Text(
                    '${_conversations.length} conversations',
                    style: FontUtils.caption(
                      context: context,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (_conversations.isNotEmpty) ...[
            SizedBox(height: 16.h),
            TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search conversations...',
                prefixIcon: Icon(
                  Icons.search,
                  color: AppColors.lightOnSurfaceVariant,
                  size: IconUtils.getResponsiveIconSize(IconSizeType.medium, context),
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.clear,
                          color: AppColors.lightOnSurfaceVariant,
                          size: IconUtils.getResponsiveIconSize(IconSizeType.medium, context),
                        ),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.lightBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16.w,
                  vertical: 12.h,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(24.w),
            decoration: const BoxDecoration(
              color: AppColors.lightBackground,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.message_outlined,
              size: 64.w,
              color: AppColors.lightOnSurfaceVariant,
            ),
          ),
          SizedBox(height: 24.h),
          Text(
            _roleService.isDoctor 
                ? 'No patient conversations yet'
                : 'No messages from your doctor',
            style: FontUtils.title(
              context: context,
              color: AppColors.lightOnSurface,
            ),
          ),
          SizedBox(height: 12.h),
          Text(
            _roleService.isDoctor 
                ? 'Start a conversation with your patients to provide better care'
                : 'Your doctor will send you messages about your health',
            style: FontUtils.body(
              context: context,
              color: AppColors.lightOnSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildConversationsList(bool isMobile) {
    final filteredConversations = _filteredConversations;

    return ListView.builder(
      padding: EdgeInsets.all(16.w),
      itemCount: filteredConversations.length,
      itemBuilder: (context, index) {
        final conversation = filteredConversations[index];
        return _buildConversationCard(conversation, isMobile);
      },
    );
  }

  Widget _buildConversationCard(Conversation conversation, bool isMobile) {
    final currentUserId = _roleService.currentUser?.id ?? '';
    final otherParticipantName = conversation.getOtherParticipantName(currentUserId);
    final otherParticipantRole = conversation.getOtherParticipantRole(currentUserId);
    final hasUnreadMessages = conversation.unreadCount > 0;

    return Container(
      margin: EdgeInsets.only(bottom: 16.h), // Increased margin for better separation
      child: Card(
        elevation: hasUnreadMessages ? 4 : 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
          side: hasUnreadMessages 
              ? BorderSide(color: AppColors.primary.withValues(alpha: 0.3), width: 1)
              : BorderSide.none,
        ),
        child: InkWell(
          onTap: () => _openConversation(conversation),
          borderRadius: BorderRadius.circular(12.r),
            child: Padding(
              padding: EdgeInsets.all(16.w),
              child: Row(
                children: [
                  _buildAvatarWithRole(otherParticipantRole, hasUnreadMessages),
                  SizedBox(width: 16.w), // Increased spacing for better visual separation
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              otherParticipantName,
                              style: FontUtils.body(
                                context: context,
                                fontWeight: hasUnreadMessages 
                                    ? FontWeight.w700 
                                    : FontWeight.w600,
                                color: AppColors.lightOnSurface,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Text(
                            conversation.lastMessage?.formattedTimestamp ?? '',
                            style: FontUtils.caption(
                              context: context,
                              color: hasUnreadMessages 
                                  ? AppColors.primary 
                                  : AppColors.lightOnSurfaceVariant,
                              fontWeight: hasUnreadMessages 
                                  ? FontWeight.w600 
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4.h),
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8.w, // Increased horizontal padding
                                vertical: 3.h,  // Increased vertical padding
                              ),
                              decoration: BoxDecoration(
                                color: _getRoleColor(otherParticipantRole).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6.r), // Increased border radius
                              ),
                              child: Text(
                                otherParticipantRole.toUpperCase(),
                                style: FontUtils.caption(
                                  context: context,
                                  color: _getRoleColor(otherParticipantRole),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          if (conversation.lastMessage?.isUrgent == true) ...[
                            SizedBox(width: 8.w),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 6.w,
                                vertical: 2.h,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.error.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4.r),
                              ),
                              child: Text(
                                'URGENT',
                                style: FontUtils.caption(
                                  context: context,
                                  color: AppColors.error,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        conversation.lastMessage?.content ?? 'No messages yet',
                        style: FontUtils.body(
                          context: context,
                          color: hasUnreadMessages 
                              ? AppColors.lightOnSurface 
                              : AppColors.lightOnSurfaceVariant,
                          fontWeight: hasUnreadMessages 
                              ? FontWeight.w500 
                              : FontWeight.normal,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8.w),
                Column(
                  children: [
                    if (hasUnreadMessages)
                      Container(
                        padding: EdgeInsets.all(6.w),
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          conversation.unreadCount.toString(),
                          style: FontUtils.caption(
                            context: context,
                            color: AppColors.onPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    SizedBox(height: 8.h),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: IconUtils.getResponsiveIconSize(IconSizeType.small, context),
                      color: AppColors.lightOnSurfaceVariant,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarWithRole(String role, bool hasUnreadMessages) {
    IconData iconData;
    Color backgroundColor;

    switch (role) {
      case 'doctor':
        iconData = Icons.local_hospital;
        backgroundColor = AppColors.primary;
        break;
      case 'patient':
        iconData = Icons.person;
        backgroundColor = AppColors.success;
        break;
      default:
        iconData = Icons.person_outline;
        backgroundColor = AppColors.lightOnSurfaceVariant;
    }

    // Use protected avatar size that won't shrink below minimum
    final avatarSize = IconUtils.getAvatarSize(
      context,
      mobileSize: 56.0,
      desktopSize: 48.0,
      minSize: 40.0, // Never smaller than 40px
    );
    final iconSize = avatarSize * 0.5; // Icon is 50% of avatar size

    return Stack(
      children: [
        Container(
          width: avatarSize,
          height: avatarSize,
          decoration: BoxDecoration(
            color: hasUnreadMessages 
                ? backgroundColor 
                : backgroundColor.withValues(alpha: 0.7),
            shape: BoxShape.circle,
            border: hasUnreadMessages 
                ? Border.all(color: AppColors.primary, width: 2)
                : null,
          ),
          child: Icon(
            iconData,
            color: Colors.white,
            size: iconSize,
          ),
        ),
        // Online status indicator
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            width: IconUtils.getStatusIndicatorSize(context),
            height: IconUtils.getStatusIndicatorSize(context),
            decoration: BoxDecoration(
              color: AppColors.success,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white,
                width: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'doctor':
        return AppColors.primary;
      case 'patient':
        return AppColors.success;
      default:
        return AppColors.lightOnSurfaceVariant;
    }
  }

  void _openConversation(Conversation conversation) {
    // For now, show a simple dialog. In a real app, this would navigate to a chat screen
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Chat with ${conversation.getOtherParticipantName(_roleService.currentUser?.id ?? '')}'),
        content: const Text('Full chat interface would be implemented here with real-time messaging.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showNewMessageDialog() {
    if (!_roleService.isDoctor) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Message'),
        content: const Text('Select a patient to start a new conversation. This feature would show a list of your assigned patients.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Select Patient'),
          ),
        ],
      ),
    );
  }
}
