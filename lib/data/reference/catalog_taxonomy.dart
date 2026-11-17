import '../models/category.dart';

/// Nijaora's launch taxonomy.
///
/// Services use parent categories with specific trades underneath. Products
/// use a separate tree so the Products section never mixes a "plumber" with a
/// "ready-made dress". Existing IDs (`tailoring`, `plumbing`, `electrical`,
/// `carpentry`, `hair-makeup`, `fashion`) are preserved so current business
/// records keep working.
List<Category> buildCatalogCategories() {
  final categories = <Category>[];

  Category parent(
    String id,
    String name,
    String description, {
    CategoryKind kind = CategoryKind.service,
    List<String> synonyms = const [],
  }) {
    final category = Category(
      id: id,
      name: name,
      description: description,
      synonyms: synonyms,
      kind: kind,
    );
    categories.add(category);
    return category;
  }

  void child(
    String id,
    String parentId,
    String name,
    String description, {
    CategoryKind kind = CategoryKind.service,
    List<String> synonyms = const [],
  }) {
    categories.add(
      Category(
        id: id,
        parentId: parentId,
        name: name,
        description: description,
        synonyms: synonyms,
        kind: kind,
      ),
    );
  }

  // 1. Construction & Building
  parent(
    'construction-building',
    'Construction & Building',
    'Builders, masons and finishing trades',
    synonyms: const ['construction', 'builder', 'building', 'site work'],
  );
  child('bricklaying', 'construction-building', 'Bricklaying & Masonry',
      'Bricklayers and masons for walls, blocks and plastering',
      synonyms: const ['bricklayer', 'mason', 'blockwork', 'plaster']);
  child('concrete', 'construction-building', 'Concrete & Blockwork',
      'Concrete casting, foundations and block moulding',
      synonyms: const ['concrete', 'foundation', 'casting']);
  child('roofing', 'construction-building', 'Roofing',
      'Roof installation, repairs and waterproofing',
      synonyms: const ['roofer', 'roof', 'aluminium roof', 'stone coated']);
  child('tiling', 'construction-building', 'Tiling & Flooring',
      'Floor and wall tiles, marble and terrazzo',
      synonyms: const ['tiler', 'tiles', 'flooring', 'marble']);
  child('welding', 'construction-building', 'Welding & Metalwork',
      'Gates, railings, burglar bars and metal fabrication',
      synonyms: const ['welder', 'gate', 'railing', 'metal work']);
  child('aluminium-glass', 'construction-building', 'Aluminium & Glass',
      'Windows, sliding doors, mirrors and glass fittings',
      synonyms: const ['aluminium', 'glass', 'window', 'sliding door']);
  child('building-engineer', 'construction-building', 'Building Engineers',
      'Structural and civil engineering support',
      synonyms: const ['engineer', 'structural', 'civil engineer']);
  child('surveying', 'construction-building', 'Land Surveying',
      'Land measurement, demarcation and survey plans',
      synonyms: const ['surveyor', 'land survey', 'demarcation']);

  // 2. Home Repairs & Maintenance
  parent(
    'home-repairs',
    'Home Repairs & Maintenance',
    'Plumbers, electricians and repair technicians',
    synonyms: const ['repair', 'maintenance', 'handyman', 'home service'],
  );
  child(
    'plumbing',
    'home-repairs',
    'Plumbing',
    'Leaks, pipes, pumps and water systems',
    synonyms: const [
      'plumber', 'pipe', 'leak', 'water', 'borehole', 'tap', 'tank',
    ],
  );
  child(
    'electrical',
    'home-repairs',
    'Electrical',
    'Wiring, repairs, inverters and solar',
    synonyms: const [
      'electrician', 'wiring', 'socket', 'light', 'generator', 'inverter',
      'solar', 'meter',
    ],
  );
  child('painting', 'home-repairs', 'Painting & Finishing',
      'Interior and exterior painting, POP and screeding',
      synonyms: const ['painter', 'paint', 'pop', 'screeding']);
  child('ac-technician', 'home-repairs', 'AC & Refrigeration',
      'Air-conditioner, fridge and freezer repairs',
      synonyms: const ['ac', 'air conditioner', 'fridge', 'freezer']);
  child('generator-technician', 'home-repairs', 'Generator & Inverter',
      'Generator servicing, repairs and inverter installation',
      synonyms: const ['generator', 'inverter', 'gen mechanic']);
  child('appliance-repair', 'home-repairs', 'Appliance Repair',
      'Washing machines, microwaves and home appliances',
      synonyms: const ['appliance', 'washing machine', 'microwave']);
  child('solar-installation', 'home-repairs', 'Solar Installation',
      'Solar panels, batteries and off-grid systems',
      synonyms: const ['solar', 'panel', 'battery', 'inverter']);
  child('handyman', 'home-repairs', 'Handyman',
      'Small repairs, fittings and odd jobs',
      synonyms: const ['handyman', 'odd jobs', 'repairs']);

  // 3. Fashion & Tailoring
  parent(
    'fashion-tailoring',
    'Fashion & Tailoring',
    'Tailors, designers and footwear makers',
    synonyms: const ['fashion', 'tailor', 'sewing', 'clothing'],
  );
  child(
    'tailoring',
    'fashion-tailoring',
    'Tailoring & Seamstress',
    'Tailors, seamstresses and custom clothing',
    synonyms: const [
      'tailor', 'seamstress', 'fashion designer', 'sewing', 'agbada',
      'ankara', 'dress', 'kaftan',
    ],
  );
  child('fashion-designer', 'fashion-tailoring', 'Fashion Designers',
      'Bespoke designs, bridal and ready-to-wear',
      synonyms: const ['designer', 'bridal', 'bespoke', 'ready to wear']);
  child('shoemaker', 'fashion-tailoring', 'Shoemakers',
      'Custom shoes, sandals and shoe repairs',
      synonyms: const ['shoe', 'cobbler', 'sandal', 'footwear']);
  child('wig-maker', 'fashion-tailoring', 'Wig Makers',
      'Wig construction, styling and revamping',
      synonyms: const ['wig', 'hair vendor', 'frontal']);
  child('embroidery', 'fashion-tailoring', 'Embroidery & Beading',
      'Machine embroidery, beading and applique',
      synonyms: const ['embroidery', 'beading', 'applique']);
  child(
    'fashion',
    'fashion-tailoring',
    'Fashion & Accessories',
    'Ready-to-wear, bags and accessories',
    synonyms: const [
      'fashion', 'clothes', 'boutique', 'accessories', 'bags', 'shoes',
      'jewellery', 'jewelry',
    ],
  );

  // 4. Beauty & Personal Care
  parent(
    'beauty-personal-care',
    'Beauty & Personal Care',
    'Barbers, hairdressers, makeup and nails',
    synonyms: const ['beauty', 'grooming', 'personal care'],
  );
  child('barber', 'beauty-personal-care', 'Barbers',
      'Haircuts, shaving and beard grooming',
      synonyms: const ['barber', 'haircut', 'shave', 'beard']);
  child('hairdresser', 'beauty-personal-care', 'Hairdressers',
      'Braids, weaves, styling and treatments',
      synonyms: const ['hairdresser', 'braids', 'weave', 'stylist']);
  child(
    'hair-makeup',
    'beauty-personal-care',
    'Hair & Makeup',
    'Hair styling, bridal and event makeup',
    synonyms: const [
      'makeup', 'makeup artist', 'hair', 'hairstylist', 'gele', 'braids',
      'beauty', 'bridal',
    ],
  );
  child('makeup-artist', 'beauty-personal-care', 'Makeup Artists',
      'Bridal, editorial and event makeup',
      synonyms: const ['mua', 'makeup', 'bridal makeup']);
  child('nail-technician', 'beauty-personal-care', 'Nail Technicians',
      'Manicure, pedicure, gel and acrylic nails',
      synonyms: const ['nails', 'manicure', 'pedicure', 'gel']);
  child('spa-massage', 'beauty-personal-care', 'Spa & Massage',
      'Massage, spa treatments and wellness',
      synonyms: const ['spa', 'massage', 'wellness']);
  child('skincare', 'beauty-personal-care', 'Skincare Specialists',
      'Facials, skincare consultations and treatments',
      synonyms: const ['skincare', 'facial', 'skin']);

  // 5. Automotive Services
  parent(
    'automotive-services',
    'Automotive Services',
    'Mechanics, auto electricians and car care',
    synonyms: const ['car', 'automobile', 'vehicle', 'auto'],
  );
  child('mechanic', 'automotive-services', 'Mechanics',
      'Engine, suspension and general car repairs',
      synonyms: const ['mechanic', 'engine', 'car repair', 'suspension']);
  child('auto-electrician', 'automotive-services', 'Auto Electricians',
      'Car wiring, batteries and electrical faults',
      synonyms: const ['auto electrician', 'car wiring', 'battery']);
  child('vulcanizer', 'automotive-services', 'Vulcanizers',
      'Tyre repairs, balancing and inflation',
      synonyms: const ['vulcanizer', 'tyre', 'tire', 'wheel']);
  child('panel-beater', 'automotive-services', 'Panel Beaters',
      'Body repairs, dent removal and spraying',
      synonyms: const ['panel beater', 'body work', 'dent', 'spray']);
  child('car-wash', 'automotive-services', 'Car Wash & Detailing',
      'Washing, polishing and interior detailing',
      synonyms: const ['car wash', 'detailing', 'polish']);
  child('auto-painter', 'automotive-services', 'Auto Painters',
      'Car painting and colour matching',
      synonyms: const ['auto paint', 'car paint', 'spray painter']);
  child('wheel-alignment', 'automotive-services', 'Wheel Alignment',
      'Alignment, balancing and suspension checks',
      synonyms: const ['alignment', 'balancing', 'wheel']);

  // 6. Technology & Electronics
  parent(
    'technology-electronics',
    'Technology & Electronics',
    'Phone, laptop and IT support',
    synonyms: const ['tech', 'electronics', 'gadget', 'it'],
  );
  child('phone-repair', 'technology-electronics', 'Phone Repairers',
      'Screen replacement, battery and software repairs',
      synonyms: const ['phone repair', 'screen', 'battery', 'iphone', 'android']);
  child('laptop-repair', 'technology-electronics', 'Laptop & Computer Repair',
      'Laptop repairs, upgrades and data recovery',
      synonyms: const ['laptop', 'computer', 'repair', 'data recovery']);
  child('it-technician', 'technology-electronics', 'IT Technicians',
      'Computer setup, networking and support',
      synonyms: const ['it', 'technician', 'support']);
  child('web-developer', 'technology-electronics', 'Web Developers',
      'Websites, e-commerce and landing pages',
      synonyms: const ['website', 'web', 'developer', 'ecommerce']);
  child('app-developer', 'technology-electronics', 'App Developers',
      'Mobile apps and software products',
      synonyms: const ['app', 'mobile app', 'software']);
  child('cctv-installer', 'technology-electronics', 'CCTV & Security',
      'CCTV, alarms and access control',
      synonyms: const ['cctv', 'camera', 'security', 'alarm']);
  child('network-engineer', 'technology-electronics', 'Network Engineers',
      'Wi-Fi, cabling and network setup',
      synonyms: const ['network', 'wifi', 'cabling']);

  // 7. Furniture & Woodwork
  parent(
    'furniture-woodwork',
    'Furniture & Woodwork',
    'Furniture makers, carpenters and upholsterers',
    synonyms: const ['furniture', 'wood', 'woodwork'],
  );
  child(
    'carpentry',
    'furniture-woodwork',
    'Carpentry',
    'Furniture, fittings and woodwork',
    synonyms: const [
      'carpenter', 'furniture', 'wood', 'cabinet', 'wardrobe', 'bed',
      'table', 'kitchen cabinet',
    ],
  );
  child('furniture-maker', 'furniture-woodwork', 'Furniture Makers',
      'Custom sofas, beds, tables and wardrobes',
      synonyms: const ['furniture', 'sofa', 'bed', 'table', 'wardrobe']);
  child('upholsterer', 'furniture-woodwork', 'Upholsterers',
      'Sofa upholstery, cushions and re-covering',
      synonyms: const ['upholstery', 'sofa', 'cushion']);
  child('cabinet-maker', 'furniture-woodwork', 'Cabinet Makers',
      'Kitchen cabinets, wardrobes and storage',
      synonyms: const ['cabinet', 'kitchen', 'wardrobe', 'storage']);
  child('wood-carver', 'furniture-woodwork', 'Wood Carvers',
      'Carved doors, panels and decorative wood',
      synonyms: const ['carving', 'wood carving', 'door']);
  child('interior-decorator', 'furniture-woodwork', 'Interior Decorators',
      'Interior styling, curtains and space planning',
      synonyms: const ['interior', 'decor', 'curtain', 'styling']);

  // 8. Cleaning & Domestic Services
  parent(
    'cleaning-domestic',
    'Cleaning & Domestic Services',
    'Cleaners, laundry, gardeners and pest control',
    synonyms: const ['cleaning', 'domestic', 'home service'],
  );
  child('home-cleaner', 'cleaning-domestic', 'Home Cleaners',
      'Deep cleaning, move-in and move-out cleaning',
      synonyms: const ['cleaner', 'deep clean', 'house cleaning']);
  child('laundry', 'cleaning-domestic', 'Laundry & Dry Cleaning',
      'Wash, ironing, dry cleaning and pickup',
      synonyms: const ['laundry', 'dry cleaning', 'ironing', 'wash']);
  child('gardener', 'cleaning-domestic', 'Gardeners',
      'Lawn care, pruning and garden maintenance',
      synonyms: const ['gardener', 'lawn', 'pruning']);
  child('pest-control', 'cleaning-domestic', 'Pest Control',
      'Rats, cockroaches, termites and bedbugs',
      synonyms: const ['pest', 'fumigation', 'termite', 'cockroach', 'rat']);
  child('fumigation', 'cleaning-domestic', 'Fumigation',
      'Fumigation and disinfection services',
      synonyms: const ['fumigation', 'disinfection', 'sanitise']);
  child('office-cleaning', 'cleaning-domestic', 'Office Cleaning',
      'Office, shop and commercial cleaning',
      synonyms: const ['office cleaning', 'commercial cleaning']);
  child('pool-cleaning', 'cleaning-domestic', 'Pool Cleaning',
      'Swimming pool cleaning and maintenance',
      synonyms: const ['pool', 'swimming pool']);

  // 9. Food & Catering
  parent(
    'food-catering',
    'Food & Catering',
    'Caterers, bakers and food vendors',
    synonyms: const ['food', 'catering', 'kitchen'],
  );
  child('caterer', 'food-catering', 'Caterers',
      'Event catering, buffets and bulk meals',
      synonyms: const ['caterer', 'catering', 'buffet', 'event food']);
  child('baker', 'food-catering', 'Bakers',
      'Bread, pastries and baked goods',
      synonyms: const ['baker', 'bread', 'pastry']);
  child('cake-maker', 'food-catering', 'Cake Makers',
      'Birthday, wedding and custom cakes',
      synonyms: const ['cake', 'wedding cake', 'birthday cake']);
  child('small-chops', 'food-catering', 'Small Chops Vendors',
      'Small chops, snacks and party packs',
      synonyms: const ['small chops', 'snacks', 'puff puff', 'samosa']);
  child('food-vendor', 'food-catering', 'Food Vendors',
      'Local meals, lunch packs and daily food',
      synonyms: const ['food vendor', 'lunch', 'local food', 'mama put']);
  child('private-chef', 'food-catering', 'Private Chefs',
      'Private dining, meal prep and home chefs',
      synonyms: const ['private chef', 'meal prep', 'chef']);
  child('bartender', 'food-catering', 'Event Bartenders',
      'Cocktails, drinks and event bar service',
      synonyms: const ['bartender', 'cocktail', 'drinks']);

  // 10. Events & Creative Services
  parent(
    'events-creative',
    'Events & Creative Services',
    'Photographers, decorators, DJs and designers',
    synonyms: const ['event', 'creative', 'media'],
  );
  child('photographer', 'events-creative', 'Photographers',
      'Events, portraits, product and lifestyle photography',
      synonyms: const ['photographer', 'photo', 'portrait', 'product shoot']);
  child('videographer', 'events-creative', 'Videographers',
      'Event coverage, music videos and video editing',
      synonyms: const ['videographer', 'video', 'coverage', 'editing']);
  child('decorator', 'events-creative', 'Decorators',
      'Event decor, rentals and styling',
      synonyms: const ['decorator', 'event decor', 'rentals', 'styling']);
  child('dj', 'events-creative', 'DJs',
      'Parties, weddings and event DJs',
      synonyms: const ['dj', 'disc jockey', 'music']);
  child('graphic-designer', 'events-creative', 'Graphic Designers',
      'Logos, flyers, branding and social media design',
      synonyms: const ['graphic designer', 'logo', 'flyer', 'branding']);
  child('printer', 'events-creative', 'Printers',
      'Flyers, banners, shirts and large format printing',
      synonyms: const ['printer', 'printing', 'banner', 'flyer']);
  child('event-planner', 'events-creative', 'Event Planners',
      'Wedding, birthday and corporate event planning',
      synonyms: const ['event planner', 'wedding planner', 'planner']);
  child('mc', 'events-creative', 'MCs & Hosts',
      'Event hosts, MCs and anchors',
      synonyms: const ['mc', 'host', 'anchor']);
  child('sound-engineer', 'events-creative', 'Sound Engineers',
      'Sound setup, mixing and live audio',
      synonyms: const ['sound', 'audio', 'mixer']);
  child('florist', 'events-creative', 'Florists',
      'Flowers, bouquets and event florals',
      synonyms: const ['florist', 'flowers', 'bouquet']);

  // 11. Crafts & Handmade Products
  parent(
    'crafts-handmade',
    'Crafts & Handmade Products',
    'Jewellery, beadwork, leather and candles',
    synonyms: const ['craft', 'handmade', 'artisan'],
  );
  child('jewellery-maker', 'crafts-handmade', 'Jewellery Makers',
      'Custom jewellery, repairs and precious stones',
      synonyms: const ['jewellery', 'jewelry', 'jeweller', 'gold', 'silver']);
  child('bead-maker', 'crafts-handmade', 'Bead Makers',
      'Beaded jewellery, waist beads and accessories',
      synonyms: const ['beads', 'beadwork', 'waist beads']);
  child('leatherworker', 'crafts-handmade', 'Leatherworkers',
      'Leather bags, belts, sandals and wallets',
      synonyms: const ['leather', 'bag', 'belt', 'wallet']);
  child('candle-maker', 'crafts-handmade', 'Candle Makers',
      'Scented candles, wax melts and gifts',
      synonyms: const ['candle', 'wax', 'scented']);
  child('soap-maker', 'crafts-handmade', 'Soap Makers',
      'Handmade soap, body butter and natural care',
      synonyms: const ['soap', 'body butter', 'natural']);
  child('pottery', 'crafts-handmade', 'Pottery & Ceramics',
      'Handmade pottery, ceramics and clay work',
      synonyms: const ['pottery', 'ceramics', 'clay']);
  child('crochet', 'crafts-handmade', 'Crochet & Knitting',
      'Crochet, knitting and handmade textiles',
      synonyms: const ['crochet', 'knitting', 'yarn']);

  // 12. Agriculture & Outdoor Services
  parent(
    'agriculture-outdoor',
    'Agriculture & Outdoor Services',
    'Farmers, landscapers and irrigation',
    synonyms: const ['agriculture', 'farm', 'outdoor'],
  );
  child('farmer', 'agriculture-outdoor', 'Farmers',
      'Crop farming, produce and farm services',
      synonyms: const ['farmer', 'crop', 'farm', 'produce']);
  child('fish-farmer', 'agriculture-outdoor', 'Fish Farmers',
      'Catfish, tilapia and fish farming',
      synonyms: const ['fish', 'catfish', 'aquaculture']);
  child('poultry', 'agriculture-outdoor', 'Poultry Farmers',
      'Chicken, eggs and poultry supplies',
      synonyms: const ['poultry', 'chicken', 'eggs']);
  child('landscaper', 'agriculture-outdoor', 'Landscapers',
      'Landscaping, lawns and outdoor design',
      synonyms: const ['landscaper', 'landscaping', 'lawn']);
  child('irrigation', 'agriculture-outdoor', 'Irrigation Technicians',
      'Irrigation systems, pumps and water management',
      synonyms: const ['irrigation', 'pump', 'water system']);
  child('agro-consultant', 'agriculture-outdoor', 'Agro Consultants',
      'Farm planning, soil and agribusiness advice',
      synonyms: const ['agro', 'consultant', 'soil', 'farm advice']);
  child('tree-felling', 'agriculture-outdoor', 'Tree Felling',
      'Tree cutting, pruning and stump removal',
      synonyms: const ['tree felling', 'tree cutting', 'stump']);

  // 13. Moving & Delivery
  parent(
    'moving-delivery',
    'Moving & Delivery',
    'Movers, dispatch riders and logistics',
    synonyms: const ['moving', 'delivery', 'logistics'],
  );
  child('mover', 'moving-delivery', 'Movers',
      'House, office and furniture moving',
      synonyms: const ['mover', 'moving', 'relocation']);
  child('dispatch-rider', 'moving-delivery', 'Dispatch Riders',
      'Same-day dispatch and errand delivery',
      synonyms: const ['dispatch', 'rider', 'errand', 'same day']);
  child('delivery', 'moving-delivery', 'Delivery Providers',
      'Parcel, food and bulk delivery',
      synonyms: const ['delivery', 'parcel', 'courier']);
  child('logistics', 'moving-delivery', 'Logistics Companies',
      'Haulage, freight and supply chain',
      synonyms: const ['logistics', 'haulage', 'freight']);
  child('truck-hire', 'moving-delivery', 'Truck Hire',
      'Trucks, vans and construction haulage',
      synonyms: const ['truck', 'van', 'hire']);
  child('packing', 'moving-delivery', 'Packing Services',
      'Packing, wrapping and unpacking',
      synonyms: const ['packing', 'wrapping', 'unpacking']);

  // 14. Tutoring & Skilled Services
  parent(
    'tutoring-skills',
    'Tutoring & Skilled Services',
    'Tutors, instructors and exam prep',
    synonyms: const ['tutor', 'lesson', 'training', 'instructor'],
  );
  child('private-tutor', 'tutoring-skills', 'Private Tutors',
      'Home and online tutoring for school subjects',
      synonyms: const ['tutor', 'lesson', 'home tutor', 'school']);
  child('music-instructor', 'tutoring-skills', 'Music Instructors',
      'Piano, guitar, drums and voice lessons',
      synonyms: const ['music', 'piano', 'guitar', 'drums', 'voice']);
  child('sewing-instructor', 'tutoring-skills', 'Sewing Instructors',
      'Tailoring and fashion design training',
      synonyms: const ['sewing', 'tailoring school', 'fashion training']);
  child('language-tutor', 'tutoring-skills', 'Language Tutors',
      'English, French, Yoruba, Igbo and Hausa',
      synonyms: const ['language', 'english', 'french', 'yoruba', 'igbo']);
  child('exam-prep', 'tutoring-skills', 'Exam Prep',
      'JAMB, WAEC, NECO and IELTS preparation',
      synonyms: const ['jamb', 'waec', 'neco', 'ielts', 'exam']);
  child('coding-instructor', 'tutoring-skills', 'Coding Instructors',
      'Coding, robotics and digital skills for children',
      synonyms: const ['coding', 'programming', 'robotics', 'digital skills']);
  child('driving-instructor', 'tutoring-skills', 'Driving Instructors',
      'Driving lessons and licence preparation',
      synonyms: const ['driving', 'driving school', 'licence']);

  // Products tree
  parent(
    'products-fashion',
    'Ready-made Clothing & Fashion',
    'Clothes, shoes, bags and accessories',
    kind: CategoryKind.product,
    synonyms: const ['clothing', 'fashion', 'shoes', 'bags'],
  );
  child('product-clothing', 'products-fashion', 'Clothing',
      'Ready-to-wear clothes for men, women and children',
      kind: CategoryKind.product,
      synonyms: const ['clothes', 'dress', 'shirt', 'trouser']);
  child('product-shoes', 'products-fashion', 'Shoes & Bags',
      'Shoes, sandals, bags and purses',
      kind: CategoryKind.product,
      synonyms: const ['shoes', 'bags', 'sandals', 'purse']);
  child('product-accessories', 'products-fashion', 'Accessories',
      'Belts, watches, jewellery and fashion accessories',
      kind: CategoryKind.product,
      synonyms: const ['accessories', 'watch', 'belt', 'jewellery']);

  parent(
    'products-furniture',
    'Furniture & Home Decor',
    'Furniture, decor and home textiles',
    kind: CategoryKind.product,
    synonyms: const ['furniture', 'decor', 'home'],
  );
  child('product-furniture', 'products-furniture', 'Furniture',
      'Sofas, beds, tables and storage',
      kind: CategoryKind.product,
      synonyms: const ['sofa', 'bed', 'table', 'chair']);
  child('product-decor', 'products-furniture', 'Home Decor',
      'Vases, wall art, mirrors and decor pieces',
      kind: CategoryKind.product,
      synonyms: const ['decor', 'vase', 'mirror', 'wall art']);
  child('product-bedding', 'products-furniture', 'Bedding & Textiles',
      'Bedsheets, curtains, towels and pillows',
      kind: CategoryKind.product,
      synonyms: const ['bedsheet', 'curtain', 'towel', 'pillow']);

  parent(
    'products-crafts',
    'Handmade Crafts',
    'Jewellery, beadwork, leather and candles',
    kind: CategoryKind.product,
    synonyms: const ['crafts', 'handmade', 'artisan'],
  );
  child('product-jewellery', 'products-crafts', 'Jewellery',
      'Handmade and fine jewellery',
      kind: CategoryKind.product,
      synonyms: const ['jewellery', 'jewelry', 'necklace', 'earrings']);
  child('product-beadwork', 'products-crafts', 'Beadwork',
      'Beaded bags, waist beads and accessories',
      kind: CategoryKind.product,
      synonyms: const ['beads', 'beadwork', 'waist beads']);
  child('product-leather', 'products-crafts', 'Leather Goods',
      'Leather bags, belts, wallets and sandals',
      kind: CategoryKind.product,
      synonyms: const ['leather', 'bag', 'belt', 'wallet']);
  child('product-candles', 'products-crafts', 'Candles & Soaps',
      'Scented candles, soaps and body care',
      kind: CategoryKind.product,
      synonyms: const ['candle', 'soap', 'body butter']);

  parent(
    'products-food',
    'Food & Beverages',
    'Packaged food, bakery and drinks',
    kind: CategoryKind.product,
    synonyms: const ['food', 'beverages', 'drinks'],
  );
  child('product-food', 'products-food', 'Packaged Food',
      'Spices, sauces, snacks and packaged meals',
      kind: CategoryKind.product,
      synonyms: const ['food', 'spices', 'sauce', 'snacks']);
  child('product-bakery', 'products-food', 'Bakery & Confectionery',
      'Bread, cakes, pastries and sweets',
      kind: CategoryKind.product,
      synonyms: const ['bakery', 'bread', 'cake', 'pastry']);
  child('product-drinks', 'products-food', 'Drinks',
      'Juices, zobo, palm wine and soft drinks',
      kind: CategoryKind.product,
      synonyms: const ['drinks', 'juice', 'zobo', 'wine']);

  parent(
    'products-beauty',
    'Beauty & Personal Care Products',
    'Skincare, haircare and cosmetics',
    kind: CategoryKind.product,
    synonyms: const ['beauty products', 'skincare', 'cosmetics'],
  );
  child('product-skincare', 'products-beauty', 'Skincare',
      'Creams, oils, serums and natural skincare',
      kind: CategoryKind.product,
      synonyms: const ['skincare', 'cream', 'oil', 'serum']);
  child('product-haircare', 'products-beauty', 'Haircare',
      'Shampoo, conditioner, oils and hair products',
      kind: CategoryKind.product,
      synonyms: const ['haircare', 'shampoo', 'conditioner']);
  child('product-cosmetics', 'products-beauty', 'Cosmetics',
      'Makeup, lashes and beauty tools',
      kind: CategoryKind.product,
      synonyms: const ['makeup', 'cosmetics', 'lashes']);

  parent(
    'products-electronics',
    'Electronics & Gadgets',
    'Phones, computers and gadgets',
    kind: CategoryKind.product,
    synonyms: const ['electronics', 'gadgets', 'phones'],
  );
  child('product-phones', 'products-electronics', 'Phones & Accessories',
      'Phones, chargers, cases and screen protectors',
      kind: CategoryKind.product,
      synonyms: const ['phone', 'charger', 'case']);
  child('product-computers', 'products-electronics', 'Computers',
      'Laptops, desktops and computer accessories',
      kind: CategoryKind.product,
      synonyms: const ['laptop', 'computer', 'desktop']);
  child('product-gadgets', 'products-electronics', 'Gadgets',
      'Smart watches, speakers and small electronics',
      kind: CategoryKind.product,
      synonyms: const ['gadget', 'watch', 'speaker']);

  parent(
    'products-building',
    'Building Materials',
    'Tiles, paint, hardware and fittings',
    kind: CategoryKind.product,
    synonyms: const ['building materials', 'hardware'],
  );
  child('product-tiles', 'products-building', 'Tiles',
      'Floor tiles, wall tiles and marble',
      kind: CategoryKind.product,
      synonyms: const ['tiles', 'marble', 'floor']);
  child('product-paint', 'products-building', 'Paint',
      'Emulsion, gloss, texture and painting tools',
      kind: CategoryKind.product,
      synonyms: const ['paint', 'emulsion', 'gloss']);
  child('product-hardware', 'products-building', 'Hardware',
      'Doors, locks, pipes, tools and fittings',
      kind: CategoryKind.product,
      synonyms: const ['hardware', 'lock', 'pipe', 'tools']);

  parent(
    'products-agriculture',
    'Agricultural Products',
    'Fresh produce, grains and livestock',
    kind: CategoryKind.product,
    synonyms: const ['agriculture', 'farm produce'],
  );
  child('product-produce', 'products-agriculture', 'Fresh Produce',
      'Vegetables, fruits and fresh farm produce',
      kind: CategoryKind.product,
      synonyms: const ['vegetables', 'fruits', 'produce']);
  child('product-grains', 'products-agriculture', 'Grains & Tubers',
      'Rice, beans, yam, garri and grains',
      kind: CategoryKind.product,
      synonyms: const ['rice', 'beans', 'yam', 'garri', 'grains']);
  child('product-livestock', 'products-agriculture', 'Livestock & Poultry',
      'Chicken, eggs, fish and livestock',
      kind: CategoryKind.product,
      synonyms: const ['chicken', 'eggs', 'fish', 'livestock']);

  parent(
    'products-art',
    'Art & Prints',
    'Paintings, prints and framing',
    kind: CategoryKind.product,
    synonyms: const ['art', 'prints', 'painting'],
  );
  child('product-art', 'products-art', 'Art',
      'Paintings, sculptures and original art',
      kind: CategoryKind.product,
      synonyms: const ['painting', 'sculpture', 'art']);
  child('product-prints', 'products-art', 'Prints & Framing',
      'Posters, prints and picture framing',
      kind: CategoryKind.product,
      synonyms: const ['print', 'poster', 'frame']);

  parent(
    'products-baby',
    'Baby & Kids',
    'Clothing, toys and baby essentials',
    kind: CategoryKind.product,
    synonyms: const ['baby', 'kids', 'children'],
  );
  child('product-baby-clothing', 'products-baby', 'Baby Clothing',
      'Baby clothes, shoes and accessories',
      kind: CategoryKind.product,
      synonyms: const ['baby clothes', 'baby shoes']);
  child('product-toys', 'products-baby', 'Toys',
      'Educational toys, games and play items',
      kind: CategoryKind.product,
      synonyms: const ['toys', 'games', 'educational']);

  parent(
    'products-auto',
    'Automotive Parts',
    'Car parts, tyres and accessories',
    kind: CategoryKind.product,
    synonyms: const ['auto parts', 'car parts'],
  );
  child('product-auto-parts', 'products-auto', 'Auto Parts',
      'Engine parts, batteries and car accessories',
      kind: CategoryKind.product,
      synonyms: const ['auto parts', 'battery', 'engine']);
  child('product-tyres', 'products-auto', 'Tyres & Wheels',
      'Tyres, rims and wheel accessories',
      kind: CategoryKind.product,
      synonyms: const ['tyres', 'tires', 'rims', 'wheels']);

  return categories;
}

List<Category> serviceParents(List<Category> categories) => categories
    .where((category) => category.isParent && category.isService)
    .toList();

List<Category> productParents(List<Category> categories) => categories
    .where((category) => category.isParent && category.isProduct)
    .toList();

List<Category> childrenOf(List<Category> categories, String parentId) =>
    categories.where((category) => category.parentId == parentId).toList();

Category? categoryById(List<Category> categories, String id) {
  for (final category in categories) {
    if (category.id == id) return category;
  }
  return null;
}
