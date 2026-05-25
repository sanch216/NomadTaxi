package com.aistaxi.model;

public enum TransactionType {
    RIDE_PAYMENT,      // Оплата поездки клиентом
    PAYOUT,            // Выплата водителю
    REFUND,            // Возврат клиенту
    ADJUSTMENT,        // Корректировка баланса админом
    COMMISSION,        // Комиссия платформы
    BONUS,             // Бонус водителю
    PENALTY            // Штраф водителю
}
