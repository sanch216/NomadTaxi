package com.aistaxi.model;

public enum ActionType {
    // User management
    BAN_USER,
    UNBAN_USER,
    TERMINATE_DRIVER,
    REACTIVATE_DRIVER,
    UPDATE_USER_RATING,

    // Driver management
    APPROVE_DRIVER_APPLICATION,
    REJECT_DRIVER_APPLICATION,
    UPDATE_DRIVER_APPLICATION,
    ACTIVATE_DRIVER,

    // Document verification
    VERIFY_DOCUMENT,
    REJECT_DOCUMENT,

    // Financial operations
    REFUND,
    PROCESS_PAYOUT,
    ADJUST_PRICE,

    // Ride management
    CANCEL_RIDE,
    ASSIGN_DRIVER,

    // Support tickets
    RESOLVE_TICKET,
    ASSIGN_TICKET,
    UPDATE_TICKET_STATUS,
    UPDATE_TICKET_PRIORITY,
    CLOSE_TICKET,

    // Promo codes
    CREATE_PROMO,
    UPDATE_PROMO,
    DELETE_PROMO,

    // Reviews
    MODERATE_REVIEW,
    DELETE_REVIEW,

    // Settings
    UPDATE_PRICING,
    UPDATE_SURGE_SETTINGS,
    CREATE_GEOZONE,

    // Other
    SEND_NOTIFICATION,
    OTHER
}
