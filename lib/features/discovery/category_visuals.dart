import 'package:flutter/material.dart';

IconData categoryIcon(String id) => switch (id) {
      // Service parents
      'construction-building' => Icons.construction_rounded,
      'home-repairs' => Icons.home_repair_service_rounded,
      'fashion-tailoring' => Icons.checkroom_rounded,
      'beauty-personal-care' => Icons.face_retouching_natural_rounded,
      'automotive-services' => Icons.directions_car_filled_rounded,
      'technology-electronics' => Icons.devices_other_rounded,
      'furniture-woodwork' => Icons.chair_rounded,
      'cleaning-domestic' => Icons.cleaning_services_rounded,
      'food-catering' => Icons.restaurant_rounded,
      'events-creative' => Icons.celebration_rounded,
      'crafts-handmade' => Icons.handyman_rounded,
      'agriculture-outdoor' => Icons.agriculture_rounded,
      'moving-delivery' => Icons.local_shipping_rounded,
      'tutoring-skills' => Icons.school_rounded,

      // Service children (legacy IDs and common trades)
      'tailoring' => Icons.checkroom_rounded,
      'plumbing' => Icons.plumbing_rounded,
      'electrical' => Icons.electrical_services_rounded,
      'carpentry' => Icons.carpenter_rounded,
      'hair-makeup' => Icons.face_retouching_natural_rounded,
      'fashion' => Icons.shopping_bag_rounded,
      'barber' => Icons.content_cut_rounded,
      'mechanic' => Icons.car_repair_rounded,
      'phone-repair' => Icons.phone_android_rounded,
      'photographer' => Icons.photo_camera_rounded,
      'caterer' => Icons.restaurant_menu_rounded,
      'mover' => Icons.local_shipping_rounded,

      // Product parents
      'products-fashion' => Icons.shopping_bag_rounded,
      'products-furniture' => Icons.chair_alt_rounded,
      'products-crafts' => Icons.diamond_rounded,
      'products-food' => Icons.bakery_dining_rounded,
      'products-beauty' => Icons.spa_rounded,
      'products-electronics' => Icons.devices_rounded,
      'products-building' => Icons.hardware_rounded,
      'products-agriculture' => Icons.eco_rounded,
      'products-art' => Icons.palette_rounded,
      'products-baby' => Icons.child_friendly_rounded,
      'products-auto' => Icons.car_repair_rounded,
      _ => Icons.handyman_rounded,
    };
