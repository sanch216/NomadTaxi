package com.aistaxi.config;

import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.data.redis.connection.RedisConnectionFactory;
import org.springframework.data.redis.connection.lettuce.LettuceConnectionFactory;
import org.springframework.data.redis.core.StringRedisTemplate;

@Configuration
@Slf4j
public class RedisConfig {

    @Bean
    @ConditionalOnProperty(name = "spring.data.redis.host", matchIfMissing = false)
    public RedisConnectionFactory redisConnectionFactory() {
        try {
            LettuceConnectionFactory factory = new LettuceConnectionFactory();
            factory.afterPropertiesSet();
            log.info("Redis connection factory initialized");
            return factory;
        } catch (Exception e) {
            log.warn("Failed to initialize Redis connection factory: {}", e.getMessage());
            return null;
        }
    }

    @Bean
    public StringRedisTemplate stringRedisTemplate(RedisConnectionFactory redisConnectionFactory) {
        if (redisConnectionFactory == null) {
            log.warn("Redis not available - returning null StringRedisTemplate");
            return null;
        }

        try {
            StringRedisTemplate template = new StringRedisTemplate(redisConnectionFactory);
            log.info("StringRedisTemplate initialized successfully");
            return template;
        } catch (Exception e) {
            log.warn("Failed to create StringRedisTemplate: {}", e.getMessage());
            return null;
        }
    }
}
