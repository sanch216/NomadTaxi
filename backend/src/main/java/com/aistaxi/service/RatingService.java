package com.aistaxi.service;

import com.aistaxi.model.User;
import com.aistaxi.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;

@Service
@RequiredArgsConstructor
public class RatingService {

    private final UserRepository userRepository;

    /**
     * Updates a user's rating using Modified Moving Average formula:
     * Anew = ((Aold * n) + R) / (n + 1)
     * 
     * @param user      The user to update
     * @param newRating The new rating to apply (0.0 to 5.0)
     */
    @Transactional
    public void updateRating(User user, Double newRating) {
        if (newRating == null || newRating < 0.0 || newRating > 5.0) {
            throw new IllegalArgumentException("Rating must be between 0.0 and 5.0");
        }

        Double currentRating = user.getRating() != null ? user.getRating() : 0.0;
        Integer ratingCount = user.getRatingCount() != null ? user.getRatingCount() : 0;

        // Modified Moving Average: Anew = ((Aold * n) + R) / (n + 1)
        double newAverage = ((currentRating * ratingCount) + newRating) / (ratingCount + 1);

        // Round to 1 decimal place
        BigDecimal rounded = BigDecimal.valueOf(newAverage)
                .setScale(1, RoundingMode.HALF_UP);

        user.setRating(rounded.doubleValue());
        user.setRatingCount(ratingCount + 1);
        userRepository.save(user);
    }
}
