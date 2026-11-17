import '../models/business.dart';
import '../models/category.dart';
import '../models/conversation.dart';
import '../models/listing.dart';
import '../models/location_node.dart';
import '../models/review.dart';
import '../reference/catalog_taxonomy.dart';
import 'demo_locations.dart';

/// In-memory catalogue used by the demo backend and by tests.
class DemoCatalog {
  DemoCatalog._({
    required this.locations,
    required this.categories,
    required this.businesses,
    required this.reviews,
    required this.conversations,
    required this.messages,
  });

  static final DemoCatalog instance = DemoCatalog.seeded();

  final List<LocationNode> locations;
  final List<Category> categories;
  final List<Business> businesses;
  final List<Review> reviews;
  final List<Conversation> conversations;
  final List<Message> messages;

  Business? businessById(String id) {
    for (final business in businesses) {
      if (business.id == id) return business;
    }
    return null;
  }

  Category? categoryById(String id) {
    for (final category in categories) {
      if (category.id == id) return category;
    }
    return null;
  }

  void publish(Business business) {
    businesses.add(business);
  }

  factory DemoCatalog.seeded() {
    final now = DateTime.now();
    final photos = <String, List<String>>{};

    List<String> shots(String id) => photos.putIfAbsent(
          id,
          () => List.generate(5, (i) => photoUrl('$id-${i + 1}')),
        );

    final categories = buildCatalogCategories();

    final businesses = <Business>[
      _business(
        id: 'radiance-tailors',
        name: 'Radiance Tailors',
        description:
            'Bespoke agbada, kaftans and bridal pieces made in Ikeja. We fit '
            'properly, finish on time, and send progress photos.',
        categories: const ['tailoring'],
        stateId: 'ng-la',
        lgaId: 'ng-la-ikeja',
        neighbourhoodId: 'ng-la-ikeja-allen-avenue',
        baseArea: 'Allen Avenue',
        operatingModel: OperatingModel.fixedLocation,
        verification: 3,
        completeness: 0.95,
        response: 12,
        rating: 4.8,
        reviewCount: 32,
        photos: shots('radiance'),
        whatsapp: '+2348031110001',
        phone: '+2348031110001',
        hours: 'Mon-Sat, 9am-7pm',
        slug: 'radiance-tailors',
        ageDays: 210,
        listings: [
          _listing('radiance-agbada', 'radiance-tailors', ListingType.service,
              'Custom agbada (3-piece)',
              'Hand-finished agbada with tailored fit. Choose fabric or bring yours.',
              PriceType.from, 45000),
          _listing('radiance-bridal', 'radiance-tailors', ListingType.service,
              'Bridal gown', 'Consultation, design and fitting for your big day.',
              PriceType.onRequest, null),
          _listing('radiance-ankara', 'radiance-tailors', ListingType.service,
              'Ankara two-piece', 'Everyday two-piece tailored to your measurements.',
              PriceType.fixed, 18000),
          _listing('radiance-jacket', 'radiance-tailors', ListingType.product,
              'Ready-to-wear Ankara jacket',
              'Structured jacket in bold Ankara. Sizes 10-16 in store.',
              PriceType.fixed, 22000),
          _listing('radiance-headtie', 'radiance-tailors', ListingType.product,
              'Aso-oke head tie', 'Handwoven head tie in deep green and gold.',
              PriceType.fixed, 8500),
        ],
      ),
      _business(
        id: 'mama-nkechi-stitches',
        name: 'Mama Nkechi Stitches',
        description:
            'Affordable, neat tailoring in Surulere. School uniforms, everyday '
            'dresses and alterations while you wait.',
        categories: const ['tailoring'],
        stateId: 'ng-la',
        lgaId: 'ng-la-surulere',
        neighbourhoodId: 'ng-la-surulere-ojuelegba',
        baseArea: 'Ojuelegba',
        verification: 2,
        completeness: 0.82,
        response: 45,
        rating: 4.6,
        reviewCount: 18,
        photos: shots('nkechi'),
        phone: '+2348031110002',
        slug: 'mama-nkechi-stitches',
        ageDays: 140,
        listings: [
          _listing('nkechi-gown', 'mama-nkechi-stitches', ListingType.service,
              'Everyday gown', 'Simple gown sewn to your measurement.',
              PriceType.from, 12000),
          _listing('nkechi-uniform', 'mama-nkechi-stitches', ListingType.service,
              'School uniform set', 'Two sets of uniforms with name tags.',
              PriceType.fixed, 8000),
          _listing('nkechi-ready-gown', 'mama-nkechi-stitches',
              ListingType.product, 'Ready-made Ankara gown',
              'Neat everyday gown in wax print. Sizes 8-14.',
              PriceType.fixed, 15000),
        ],
      ),
      _business(
        id: 'flowfix-plumbing',
        name: 'FlowFix Plumbing',
        description:
            'Emergency plumbing across Surulere, Ikeja and Lagos Mainland. '
            'Leaks, pumps, tanks and full bathroom fittings.',
        categories: const ['plumbing'],
        stateId: 'ng-la',
        lgaId: 'ng-la-surulere',
        neighbourhoodId: 'ng-la-surulere-bode-thomas',
        baseArea: 'Bode Thomas',
        operatingModel: OperatingModel.mobile,
        serves: const [
          'ng-la-surulere',
          'ng-la-ikeja',
          'ng-la-lagos-mainland',
          'ng-la-mushin',
        ],
        verification: 2,
        completeness: 0.88,
        response: 8,
        rating: 4.7,
        reviewCount: 41,
        photos: shots('flowfix'),
        whatsapp: '+2348031110003',
        phone: '+2348031110003',
        hours: 'Daily, 7am-9pm',
        slug: 'flowfix-plumbing',
        ageDays: 260,
        listings: [
          _listing('flowfix-leak', 'flowfix-plumbing', ListingType.service,
              'Leak repair', 'Same-day leak diagnosis and repair.',
              PriceType.from, 15000),
          _listing('flowfix-pump', 'flowfix-plumbing', ListingType.service,
              'Borehole pump installation', 'Pump, tank and wiring installed and tested.',
              PriceType.onRequest, null),
        ],
      ),
      _business(
        id: 'brightspark-electricals',
        name: 'BrightSpark Electricals',
        description:
            'Certified electricians for homes and small shops. Wiring, '
            'inverters, solar and fault finding.',
        categories: const ['electrical'],
        stateId: 'ng-la',
        lgaId: 'ng-la-ikeja',
        neighbourhoodId: 'ng-la-ikeja-opebi',
        baseArea: 'Opebi',
        operatingModel: OperatingModel.mobile,
        serves: const [
          'ng-la-ikeja',
          'ng-la-oshodi-isolo',
          'ng-la-agege',
          'ng-la-ifako-ijaiye',
        ],
        verification: 2,
        completeness: 0.9,
        response: 15,
        rating: 4.9,
        reviewCount: 57,
        photos: shots('brightspark'),
        whatsapp: '+2348031110004',
        slug: 'brightspark-electricals',
        ageDays: 300,
        listings: [
          _listing('bright-wiring', 'brightspark-electricals', ListingType.service,
              'House wiring', 'Full wiring for a 2-3 bedroom home, materials quoted separately.',
              PriceType.from, 80000),
          _listing('bright-inverter', 'brightspark-electricals', ListingType.service,
              'Inverter installation', 'Supply and install inverter and batteries.',
              PriceType.from, 120000),
        ],
      ),
      _business(
        id: 'adebayo-woodworks',
        name: 'Adebayo Woodworks',
        description:
            'Solid wood furniture made in Ibadan. Dining sets, wardrobes and '
            'kitchen cabinets built to last.',
        categories: const ['carpentry'],
        stateId: 'ng-oy',
        lgaId: 'ng-oy-ibadan-north',
        neighbourhoodId: 'ng-oy-ibadan-north-bodija',
        baseArea: 'Bodija',
        verification: 2,
        completeness: 0.85,
        response: 30,
        rating: 4.8,
        reviewCount: 24,
        photos: shots('adebayo'),
        whatsapp: '+2348031110005',
        phone: '+2348031110005',
        hours: 'Mon-Sat, 8am-6pm',
        slug: 'adebayo-woodworks',
        ageDays: 190,
        listings: [
          _listing('adebayo-dining', 'adebayo-woodworks', ListingType.product,
              '6-seater dining set', 'Mahogany table with six upholstered chairs.',
              PriceType.fixed, 350000),
          _listing('adebayo-wardrobe', 'adebayo-woodworks', ListingType.service,
              'Custom wardrobe', 'Fitted wardrobe measured and built in your home.',
              PriceType.from, 180000),
          _listing('adebayo-desk', 'adebayo-woodworks', ListingType.product,
              'Solid wood office desk', 'Mahogany desk with two drawers.',
              PriceType.fixed, 145000),
          _listing('adebayo-shelf', 'adebayo-woodworks', ListingType.product,
              'Floating wall shelf set', 'Set of three solid wood shelves.',
              PriceType.fixed, 45000),
        ],
      ),
      _business(
        id: 'glow-by-tola',
        name: 'Glow by Tola',
        description:
            'Bridal and event makeup in Lekki. We travel to you across Lagos '
            'Island and Eti-Osa.',
        categories: const ['hair-makeup'],
        stateId: 'ng-la',
        lgaId: 'ng-la-eti-osa',
        neighbourhoodId: 'ng-la-eti-osa-lekki-phase-1',
        baseArea: 'Lekki Phase 1',
        operatingModel: OperatingModel.mobile,
        serves: const [
          'ng-la-eti-osa',
          'ng-la-lagos-island',
        ],
        verification: 3,
        completeness: 0.97,
        response: 20,
        rating: 4.9,
        reviewCount: 63,
        photos: shots('glow'),
        whatsapp: '+2348031110006',
        phone: '+2348031110006',
        slug: 'glow-by-tola',
        ageDays: 320,
        listings: [
          _listing('glow-bridal', 'glow-by-tola', ListingType.service,
              'Bridal makeup', 'Trial, wedding-day makeup and touch-up kit.',
              PriceType.from, 85000),
          _listing('glow-gele', 'glow-by-tola', ListingType.service,
              'Gele and makeup', 'Event-ready gele and soft glam.',
              PriceType.fixed, 45000),
          _listing('glow-touchup', 'glow-by-tola', ListingType.product,
              'Bridal touch-up kit',
              'Setting spray, blotting papers and a matching lip colour.',
              PriceType.fixed, 18000),
          _listing('glow-hair-oil', 'glow-by-tola', ListingType.product,
              'Growth hair oil', 'Rosemary and castor oil blend, 100ml.',
              PriceType.fixed, 6500),
          _listing('glow-shea', 'glow-by-tola', ListingType.product,
              'Whipped shea butter', 'Fragrance-free shea butter, 250ml.',
              PriceType.fixed, 5000),
        ],
      ),
      _business(
        id: 'lekki-threads',
        name: 'Lekki Threads',
        description:
            'Ready-to-wear Ankara and accessories, curated in Lekki. Visit the '
            'shop or ask us to reserve an item.',
        categories: const ['fashion'],
        stateId: 'ng-la',
        lgaId: 'ng-la-eti-osa',
        neighbourhoodId: 'ng-la-eti-osa-lekki-phase-1',
        baseArea: 'Lekki Phase 1',
        verification: 2,
        completeness: 0.78,
        response: 60,
        rating: 4.5,
        reviewCount: 12,
        photos: shots('lekki-threads'),
        whatsapp: '+2348031110007',
        slug: 'lekki-threads',
        ageDays: 90,
        listings: [
          _listing('threads-dress', 'lekki-threads', ListingType.product,
              'Ankara midi dress', 'Sizes 8-16 available in store.',
              PriceType.fixed, 28000),
          _listing('threads-set', 'lekki-threads', ListingType.product,
              'Two-piece set', 'Matching top and wide-leg trousers.',
              PriceType.fixed, 32000),
          _listing('threads-bag', 'lekki-threads', ListingType.product,
              'Beaded bag', 'Handmade evening bag.',
              PriceType.fixed, 15000),
          _listing('threads-scarf', 'lekki-threads', ListingType.product,
              'Silk head scarf', 'Lightweight silk scarf in jewel tones.',
              PriceType.fixed, 12000),
          _listing('threads-tote', 'lekki-threads', ListingType.product,
              'Woven market tote', 'Roomy handwoven tote for everyday use.',
              PriceType.fixed, 18000),
        ],
      ),
      _business(
        id: 'chinedu-plumbing',
        name: 'Chinedu Plumbing Services',
        description:
            'Reliable plumber based in Ikeja. Taps, toilets, pipes and small '
            'repairs. New on Nijaora.',
        categories: const ['plumbing'],
        stateId: 'ng-la',
        lgaId: 'ng-la-ikeja',
        neighbourhoodId: 'ng-la-ikeja-ogba',
        baseArea: 'Ogba',
        operatingModel: OperatingModel.mobile,
        serves: const ['ng-la-ikeja', 'ng-la-oshodi-isolo'],
        verification: 1,
        completeness: 0.45,
        response: 90,
        rating: 0,
        reviewCount: 0,
        photos: shots('chinedu').take(3).toList(),
        phone: '+2348031110008',
        slug: 'chinedu-plumbing',
        ageDays: 9,
        listings: [
          _listing('chinedu-tap', 'chinedu-plumbing', ListingType.service,
              'Tap repair', 'Fix leaking or broken taps.',
              PriceType.from, 7000),
        ],
      ),
      _business(
        id: 'ibadan-carpentry-hub',
        name: 'Ibadan Carpentry Hub',
        description:
            'A small team of carpenters serving Ibadan. Beds, cabinets and '
            'office furniture.',
        categories: const ['carpentry'],
        stateId: 'ng-oy',
        lgaId: 'ng-oy-ibadan-north',
        neighbourhoodId: 'ng-oy-ibadan-north-agbowo',
        baseArea: 'Agbowo',
        operatingModel: OperatingModel.mobile,
        serves: const [
          'ng-oy-ibadan-north',
          'ng-oy-ibadan-south-west',
          'ng-oy-egbeda',
        ],
        verification: 2,
        completeness: 0.8,
        response: 50,
        rating: 4.4,
        reviewCount: 9,
        photos: shots('ibadan-carpentry'),
        phone: '+2348031110009',
        slug: 'ibadan-carpentry-hub',
        ageDays: 70,
        listings: [
          _listing('ibadan-bed', 'ibadan-carpentry-hub', ListingType.product,
              'Bed frame', 'Hardwood bed frame, any size.',
              PriceType.from, 95000),
          _listing('ibadan-kitchen', 'ibadan-carpentry-hub', ListingType.service,
              'Kitchen cabinet', 'Measured, built and installed.',
              PriceType.onRequest, null),
          _listing('ibadan-chair', 'ibadan-carpentry-hub', ListingType.product,
              'Reading chair', 'Cushioned hardwood chair for a corner or study.',
              PriceType.fixed, 65000),
          _listing('ibadan-basket', 'ibadan-carpentry-hub', ListingType.product,
              'Woven storage basket', 'Handwoven basket with a sturdy handle.',
              PriceType.fixed, 12000),
        ],
      ),
      _business(
        id: 'amakas-accessories',
        name: "Amaka's Accessories",
        description:
            'Handmade earrings, scarves and small gifts in Surulere. Bulk '
            'orders welcome.',
        categories: const ['fashion'],
        stateId: 'ng-la',
        lgaId: 'ng-la-surulere',
        neighbourhoodId: 'ng-la-surulere-aguda',
        baseArea: 'Aguda',
        verification: 1,
        completeness: 0.7,
        response: 120,
        rating: 4.2,
        reviewCount: 4,
        photos: shots('amaka'),
        whatsapp: '+2348031110010',
        slug: 'amakas-accessories',
        ageDays: 40,
        listings: [
          _listing('amaka-earrings', 'amakas-accessories', ListingType.product,
              'Beaded earrings', 'Handmade, assorted colours.',
              PriceType.fixed, 4500),
          _listing('amaka-scarf', 'amakas-accessories', ListingType.product,
              'Silk scarf', 'Lightweight scarf, gift wrapped.',
              PriceType.fixed, 7500),
          _listing('amaka-bag', 'amakas-accessories', ListingType.product,
              'Beaded evening bag', 'Hand-beaded bag with a detachable strap.',
              PriceType.fixed, 12000),
          _listing('amaka-waist', 'amakas-accessories', ListingType.product,
              'Waist beads', 'Made to order in your colours and length.',
              PriceType.from, 3500),
        ],
      ),
      _business(
        id: 'mama-ngozi-kitchen',
        name: "Mama Ngozi's Kitchen",
        description:
            'Home-style Nigerian food cooked fresh in Surulere. Efo riro, '
            'party jollof, small chops and chilled zobo for pickup or delivery.',
        categories: const ['product-food'],
        stateId: 'ng-la',
        lgaId: 'ng-la-surulere',
        neighbourhoodId: 'ng-la-surulere-aguda',
        baseArea: 'Aguda',
        verification: 1,
        completeness: 0.76,
        response: 25,
        rating: 4.7,
        reviewCount: 9,
        photos: shots('ngozi'),
        whatsapp: '+2348031110013',
        slug: 'mama-ngozi-kitchen',
        ageDays: 90,
        listings: [
          _listing('ngozi-efo', 'mama-ngozi-kitchen', ListingType.product,
              'Efo riro & eba', 'Rich spinach stew with assorted meat and eba.',
              PriceType.fixed, 3500),
          _listing('ngozi-jollof', 'mama-ngozi-kitchen', ListingType.product,
              'Party jollof rice', 'Smoky jollof with fried plantain and chicken.',
              PriceType.fixed, 4500),
          _listing('ngozi-zobo', 'mama-ngozi-kitchen', ListingType.product,
              'Chilled zobo', 'Hibiscus drink with pineapple and ginger, 1 litre.',
              PriceType.fixed, 1500),
          _listing('ngozi-chips', 'mama-ngozi-kitchen', ListingType.product,
              'Plantain chips', 'Crunchy plantain chips, lightly salted.',
              PriceType.fixed, 2000),
        ],
      ),
      _business(
        id: 'sparkline-electricals',
        name: 'Sparkline Electricals',
        description:
            'Electrical repairs and solar setups in Ibadan. Clean work, clear '
            'pricing.',
        categories: const ['electrical'],
        stateId: 'ng-oy',
        lgaId: 'ng-oy-ibadan-north',
        neighbourhoodId: 'ng-oy-ibadan-north-mokola',
        baseArea: 'Mokola',
        operatingModel: OperatingModel.mobile,
        serves: const ['ng-oy-ibadan-north', 'ng-oy-ibadan-north-east'],
        verification: 2,
        completeness: 0.75,
        response: 35,
        rating: 4.6,
        reviewCount: 11,
        photos: shots('sparkline'),
        phone: '+2348031110011',
        slug: 'sparkline-electricals',
        ageDays: 120,
        listings: [
          _listing('spark-socket', 'sparkline-electricals', ListingType.service,
              'Socket repair', 'Diagnose and replace faulty sockets.',
              PriceType.from, 5000),
          _listing('spark-solar', 'sparkline-electricals', ListingType.service,
              'Solar panel setup', 'Sized to your home or shop.',
              PriceType.onRequest, null),
        ],
      ),
      _business(
        id: 'vi-plumbers',
        name: 'VI Plumbing Works',
        description:
            'Plumbing for homes and offices on the Island. Emergency call-outs '
            'and planned installations.',
        categories: const ['plumbing'],
        stateId: 'ng-la',
        lgaId: 'ng-la-eti-osa',
        neighbourhoodId: 'ng-la-eti-osa-victoria-island',
        baseArea: 'Victoria Island',
        operatingModel: OperatingModel.mobile,
        serves: const ['ng-la-eti-osa', 'ng-la-lagos-island'],
        verification: 2,
        completeness: 0.83,
        response: 25,
        rating: 4.7,
        reviewCount: 16,
        photos: shots('vi-plumbers'),
        whatsapp: '+2348031110012',
        slug: 'vi-plumbing-works',
        ageDays: 150,
        listings: [
          _listing('vi-leak', 'vi-plumbers', ListingType.service,
              'Emergency leak repair', 'Rapid response for burst pipes.',
              PriceType.from, 20000),
          _listing('vi-tank', 'vi-plumbers', ListingType.service,
              'Water tank installation', 'Stand, tank and plumbing connections.',
              PriceType.from, 60000),
        ],
      ),
    ];

    final reviews = <Review>[
      _review('rev-1', 'radiance-tailors', 'Adaeze O.', 5,
          'He sent progress photos every few days and the agbada fit perfectly. '
          'Finished a day before the wedding.',
          now.subtract(const Duration(days: 6)),
          reply: 'Thank you Adaeze. Enjoy the wedding!'),
      _review('rev-2', 'radiance-tailors', 'Tunde A.', 5,
          'Good communication on WhatsApp and in the app. Fair price for the quality.',
          now.subtract(const Duration(days: 19))),
      _review('rev-3', 'radiance-tailors', 'Ifeoma N.', 4,
          'Lovely work. Delivery was a few hours later than planned but he kept me updated.',
          now.subtract(const Duration(days: 41))),
      _review('rev-4', 'flowfix-plumbing', 'Bola K.', 5,
          'Came within two hours and fixed a burst pipe under the sink. No drama.',
          now.subtract(const Duration(days: 3)),
          reply: 'Thanks Bola. Call us any time.'),
      _review('rev-5', 'flowfix-plumbing', 'Emeka U.', 4,
          'Solid work. Brought his own tools and cleaned up after.',
          now.subtract(const Duration(days: 12))),
      _review('rev-6', 'glow-by-tola', 'Zainab M.', 5,
          'She understood exactly the soft glam look I wanted and the gele stayed all night.',
          now.subtract(const Duration(days: 8)),
          reply: 'Thank you Zainab! You looked beautiful.'),
      _review('rev-7', 'glow-by-tola', 'Chiamaka E.', 5,
          'On time, calm, and very professional. Booked her again for my sister.',
          now.subtract(const Duration(days: 27))),
      _review('rev-8', 'brightspark-electricals', 'Segun F.', 5,
          'Found the fault in 20 minutes after two other electricians failed.',
          now.subtract(const Duration(days: 5))),
      _review('rev-9', 'adebayo-woodworks', 'Yemi O.', 5,
          'The dining set is solid and exactly the stain we agreed.',
          now.subtract(const Duration(days: 15))),
      _review('rev-10', 'vi-plumbers', 'Ngozi I.', 5,
          'Installed our tank and fixed the pressure problem the same day.',
          now.subtract(const Duration(days: 9))),
      _review('rev-11', 'mama-ngozi-kitchen', 'Kemi A.', 5,
          'The efo riro tasted like home and the delivery was still hot.',
          now.subtract(const Duration(days: 3))),
      _review('rev-12', 'mama-ngozi-kitchen', 'Uche O.', 4,
          'Zobo was properly chilled and not too sweet. I will order again.',
          now.subtract(const Duration(days: 12))),
    ];

    final conversations = <Conversation>[
      Conversation(
        id: 'conv-radiance',
        businessId: 'radiance-tailors',
        customerId: 'demo-customer',
        listingId: 'radiance-agbada',
        lastMessage:
            'Yes, Friday is realistic. Do you want navy or black fabric?',
        lastMessageAt: now.subtract(const Duration(hours: 2)),
        unreadForCustomer: 1,
      ),
      Conversation(
        id: 'conv-flowfix',
        businessId: 'flowfix-plumbing',
        customerId: 'demo-customer',
        lastMessage: 'I will come tomorrow at 10am.',
        lastMessageAt: now.subtract(const Duration(days: 1, hours: 3)),
      ),
    ];

    final messages = <Message>[
      Message(
        id: 'msg-1',
        conversationId: 'conv-radiance',
        senderId: 'demo-customer',
        text: 'Good afternoon. I need an agbada for a wedding on Saturday. Is that realistic?',
        sentAt: now.subtract(const Duration(hours: 5)),
      ),
      Message(
        id: 'msg-2',
        conversationId: 'conv-radiance',
        senderId: 'radiance-tailors',
        isFromBusiness: true,
        text: 'Good afternoon! Congratulations. Which colour and size are you thinking?',
        sentAt: now.subtract(const Duration(hours: 4, minutes: 40)),
      ),
      Message(
        id: 'msg-3',
        conversationId: 'conv-radiance',
        senderId: 'demo-customer',
        text: 'Navy, size XL. I am in Ikeja.',
        sentAt: now.subtract(const Duration(hours: 3)),
      ),
      Message(
        id: 'msg-4',
        conversationId: 'conv-radiance',
        senderId: 'radiance-tailors',
        isFromBusiness: true,
        text:
            'Yes, Friday is realistic. Do you want navy or black fabric?',
        sentAt: now.subtract(const Duration(hours: 2)),
      ),
      Message(
        id: 'msg-5',
        conversationId: 'conv-flowfix',
        senderId: 'demo-customer',
        text: 'My kitchen tap is leaking badly. Can you come today?',
        sentAt: now.subtract(const Duration(days: 1, hours: 6)),
      ),
      Message(
        id: 'msg-6',
        conversationId: 'conv-flowfix',
        senderId: 'flowfix-plumbing',
        isFromBusiness: true,
        text: 'Send a photo of the pipe under the sink, please.',
        sentAt: now.subtract(const Duration(days: 1, hours: 5)),
      ),
      Message(
        id: 'msg-7',
        conversationId: 'conv-flowfix',
        senderId: 'demo-customer',
        text: 'Sent it now.',
        sentAt: now.subtract(const Duration(days: 1, hours: 4)),
      ),
      Message(
        id: 'msg-8',
        conversationId: 'conv-flowfix',
        senderId: 'flowfix-plumbing',
        isFromBusiness: true,
        text: 'I will come tomorrow at 10am.',
        sentAt: now.subtract(const Duration(days: 1, hours: 3)),
      ),
    ];

    return DemoCatalog._(
      locations: List.of(DemoLocations.nodes),
      categories: categories,
      businesses: businesses,
      reviews: reviews,
      conversations: conversations,
      messages: messages,
    );
  }
}

// Contextual demo photography. These are real, category-relevant images from
// Wikimedia Commons and Unsplash. Production photos will live in Supabase
// Storage; this map keeps the local/demo experience honest until then.
const _imgTailorShop =
    'https://upload.wikimedia.org/wikipedia/commons/thumb/b/b3/'
    'A_Tailor_Sewing_Clothes_in_Her_Shop.jpg/960px-'
    'A_Tailor_Sewing_Clothes_in_Her_Shop.jpg';
const _imgNigerianTailor =
    'https://upload.wikimedia.org/wikipedia/commons/thumb/3/35/'
    'A_Nigerian_tailor.jpg/960px-A_Nigerian_tailor.jpg';
const _imgNigerianTailorWork =
    'https://upload.wikimedia.org/wikipedia/commons/thumb/d/df/'
    'A_Nigerian_tailor_at_work.jpg/960px-A_Nigerian_tailor_at_work.jpg';
const _imgAgbada =
    'https://upload.wikimedia.org/wikipedia/commons/thumb/4/46/'
    'A_Nigerian_Yoruba_groom_in_an_Agbada_made_from_Ebira_fabric.jpg/'
    '960px-A_Nigerian_Yoruba_groom_in_an_Agbada_made_from_Ebira_fabric.jpg';
const _imgAnkaraDress =
    'https://upload.wikimedia.org/wikipedia/commons/thumb/6/64/'
    'A_BEAUTIFUL_Ankara_dress.jpg/960px-A_BEAUTIFUL_Ankara_dress.jpg';
const _imgGele =
    'https://upload.wikimedia.org/wikipedia/commons/thumb/5/52/'
    'A_Nigerian_Yoruba_lady_in_a_Buba_and_Gele_headtie.jpg/960px-'
    'A_Nigerian_Yoruba_lady_in_a_Buba_and_Gele_headtie.jpg';
const _imgBridalMakeup =
    'https://upload.wikimedia.org/wikipedia/commons/thumb/9/99/'
    'Bridal_makeup_in_calabar.jpg/960px-Bridal_makeup_in_calabar.jpg';
const _imgHairBraiding =
    'https://upload.wikimedia.org/wikipedia/commons/thumb/9/90/'
    'Braider_at_a_hair_salon.jpg/960px-Braider_at_a_hair_salon.jpg';
const _imgMakeupArtist =
    'https://upload.wikimedia.org/wikipedia/commons/thumb/e/e2/'
    'Makeup_artist_at_work.jpg/960px-Makeup_artist_at_work.jpg';
const _imgMakeupStudio =
    'https://upload.wikimedia.org/wikipedia/commons/thumb/f/f0/'
    'Makeup_studio_in_working_mode.jpg/960px-'
    'Makeup_studio_in_working_mode.jpg';
const _imgNigerianCarpenter =
    'https://upload.wikimedia.org/wikipedia/commons/thumb/9/90/'
    'A_Nigerian_carpenter_and_furniture_maker.jpg/960px-'
    'A_Nigerian_carpenter_and_furniture_maker.jpg';
const _imgCaneFurniture =
    'https://upload.wikimedia.org/wikipedia/commons/thumb/0/05/'
    'Cane_Furniture_Maker%2C_Kwara_State%2C_Nigeria.jpg/960px-'
    'Cane_Furniture_Maker%2C_Kwara_State%2C_Nigeria.jpg';
const _imgWoodworkers =
    'https://upload.wikimedia.org/wikipedia/commons/thumb/c/cd/'
    'Wood_workers_at_Khilgaon%2C_dhaka_05.jpg/960px-'
    'Wood_workers_at_Khilgaon%2C_dhaka_05.jpg';
const _imgCarpenter =
    'https://upload.wikimedia.org/wikipedia/commons/thumb/5/56/'
    'Carpenter_working_on_an_item_4.jpg/960px-'
    'Carpenter_working_on_an_item_4.jpg';
const _imgDiningTable =
    'https://upload.wikimedia.org/wikipedia/commons/6/65/'
    'Wooden-dining-table-set-design-in-walnut-finish.jpg';
const _imgSofa =
    'https://images.unsplash.com/photo-1555041469-a586c61ea9bc'
    '?auto=format&fit=crop&w=1200&q=80';
const _imgWardrobe =
    'https://images.unsplash.com/photo-1595428774223-ef52624120d2'
    '?auto=format&fit=crop&w=1200&q=80';
const _imgBed =
    'https://images.unsplash.com/photo-1505693416388-ac5ce068fe85'
    '?auto=format&fit=crop&w=1200&q=80';
const _imgKitchen =
    'https://images.unsplash.com/photo-1556911220-bff31c812dba'
    '?auto=format&fit=crop&w=1200&q=80';
const _imgFaucet =
    'https://images.unsplash.com/photo-1585704032915-c3400ca199e7'
    '?auto=format&fit=crop&w=1200&q=80';
const _imgPipes =
    'https://images.unsplash.com/photo-1607472586893-edb57bdc0e39'
    '?auto=format&fit=crop&w=1200&q=80';
const _imgPlumber =
    'https://upload.wikimedia.org/wikipedia/commons/thumb/b/b4/'
    'Plumber_at_work_%28retouched%29.jpg/960px-'
    'Plumber_at_work_%28retouched%29.jpg';
const _imgBathroom =
    'https://images.unsplash.com/photo-1584622650111-993a426fbf0a'
    '?auto=format&fit=crop&w=1200&q=80';
const _imgTools =
    'https://images.unsplash.com/photo-1530124566582-a618bc2615dc'
    '?auto=format&fit=crop&w=1200&q=80';
const _imgBlackElectrician =
    'https://images.unsplash.com/photo-1621905252507-b35492cc74b4'
    '?auto=format&fit=crop&w=1200&q=80';
const _imgElectrician =
    'https://upload.wikimedia.org/wikipedia/commons/thumb/3/37/'
    'Electrician_Working.jpg/960px-Electrician_Working.jpg';
const _imgElectricianMeter =
    'https://upload.wikimedia.org/wikipedia/commons/thumb/2/2d/'
    'Electricians_fixing_electricity_meter_5.jpg/960px-'
    'Electricians_fixing_electricity_meter_5.jpg';
const _imgSolarInstaller =
    'https://upload.wikimedia.org/wikipedia/commons/thumb/a/aa/'
    'Solar_panel_installer.jpg/960px-Solar_panel_installer.jpg';
const _imgGeneratorRepair =
    'https://upload.wikimedia.org/wikipedia/commons/thumb/8/89/'
    'Generator_Repair_Work.jpg/960px-Generator_Repair_Work.jpg';
const _imgBeadedJewelry =
    'https://upload.wikimedia.org/wikipedia/commons/thumb/1/19/'
    'African_beaded_jewelry_at_Taste_of_Ghana_Festival_2023.jpg/960px-'
    'African_beaded_jewelry_at_Taste_of_Ghana_Festival_2023.jpg';
const _imgAccessories =
    'https://images.unsplash.com/photo-1537832816519-689ad163238b'
    '?auto=format&fit=crop&w=1200&q=80';
const _imgPearlNecklace =
    'https://images.unsplash.com/photo-1515562141207-7a88fb7ce338'
    '?auto=format&fit=crop&w=1200&q=80';
const _imgHandbag =
    'https://images.unsplash.com/photo-1590874103328-eac38a683ce7'
    '?auto=format&fit=crop&w=1200&q=80';
const _imgSilkScarf =
    'https://upload.wikimedia.org/wikipedia/commons/thumb/5/54/'
    'Colored_silk_scarf_from_India_01.jpg/960px-'
    'Colored_silk_scarf_from_India_01.jpg';
const _imgClothingRack =
    'https://images.unsplash.com/photo-1445205170230-053b83016050'
    '?auto=format&fit=crop&w=1200&q=80';
const _imgNigerianModels =
    'https://upload.wikimedia.org/wikipedia/commons/thumb/5/51/'
    'Nigerian_fashion_models_at_work_%282%29.jpg/960px-'
    'Nigerian_fashion_models_at_work_%282%29.jpg';
const _imgWedding =
    'https://images.unsplash.com/photo-1519741497674-611481863552'
    '?auto=format&fit=crop&w=1200&q=80';
const _imgNigerianFood =
    'https://images.unsplash.com/photo-1604329760661-e71dc83f8f26'
    '?auto=format&fit=crop&w=1200&q=80';
const _imgZobo =
    'https://images.unsplash.com/photo-1544145945-f90425340c7e'
    '?auto=format&fit=crop&w=1200&q=80';
const _imgPlantainChips =
    'https://images.unsplash.com/photo-1599490659213-e2b9527bd087'
    '?auto=format&fit=crop&w=1200&q=80';

const _photoSets = <String, List<String>>{
  'radiance': [
    _imgNigerianTailor,
    _imgTailorShop,
    _imgNigerianTailorWork,
    _imgAgbada,
    _imgAnkaraDress,
  ],
  'nkechi': [
    _imgNigerianTailorWork,
    _imgTailorShop,
    _imgAnkaraDress,
    _imgAccessories,
    _imgNigerianTailor,
  ],
  'flowfix': [_imgFaucet, _imgPipes, _imgPlumber, _imgBathroom, _imgTools],
  'brightspark': [
    _imgBlackElectrician,
    _imgElectrician,
    _imgSolarInstaller,
    _imgGeneratorRepair,
    _imgElectricianMeter,
  ],
  'adebayo': [
    _imgNigerianCarpenter,
    _imgCaneFurniture,
    _imgDiningTable,
    _imgSofa,
    _imgWardrobe,
    _imgCarpenter,
  ],
  'glow': [
    _imgBridalMakeup,
    _imgHairBraiding,
    _imgMakeupArtist,
    _imgMakeupStudio,
    _imgGele,
  ],
  'lekki-threads': [
    _imgClothingRack,
    _imgAnkaraDress,
    _imgAccessories,
    _imgHandbag,
    _imgNigerianModels,
  ],
  'chinedu': [_imgFaucet, _imgPlumber, _imgPipes, _imgBathroom, _imgTools],
  'ibadan-carpentry': [
    _imgNigerianCarpenter,
    _imgCaneFurniture,
    _imgBed,
    _imgKitchen,
    _imgWoodworkers,
  ],
  'amaka': [
    _imgBeadedJewelry,
    _imgAccessories,
    _imgPearlNecklace,
    _imgHandbag,
    _imgSilkScarf,
  ],
  'sparkline': [
    _imgSolarInstaller,
    _imgGeneratorRepair,
    _imgElectrician,
    _imgElectricianMeter,
    _imgBlackElectrician,
  ],
  'vi-plumbers': [
    _imgFaucet,
    _imgPipes,
    _imgPlumber,
    _imgBathroom,
    _imgTools,
  ],
  'ngozi': [_imgNigerianFood, _imgZobo, _imgPlantainChips],
};

const _listingPhotos = <String, String>{
  'radiance-agbada': _imgAgbada,
  'radiance-bridal': _imgWedding,
  'radiance-ankara': _imgAnkaraDress,
  'nkechi-gown': _imgAnkaraDress,
  'nkechi-uniform': _imgNigerianTailorWork,
  'flowfix-leak': _imgFaucet,
  'flowfix-pump': _imgPipes,
  'bright-wiring': _imgBlackElectrician,
  'bright-inverter': _imgSolarInstaller,
  'adebayo-dining': _imgDiningTable,
  'adebayo-wardrobe': _imgWardrobe,
  'glow-bridal': _imgBridalMakeup,
  'glow-gele': _imgGele,
  'threads-dress': _imgAnkaraDress,
  'threads-set': _imgClothingRack,
  'threads-bag': _imgHandbag,
  'threads-scarf': _imgSilkScarf,
  'threads-tote': _imgHandbag,
  'radiance-jacket': _imgClothingRack,
  'radiance-headtie': _imgGele,
  'nkechi-ready-gown': _imgAnkaraDress,
  'adebayo-desk': _imgDiningTable,
  'adebayo-shelf': _imgWardrobe,
  'glow-touchup': _imgMakeupStudio,
  'glow-hair-oil': _imgBridalMakeup,
  'glow-shea': _imgMakeupStudio,
  'ibadan-chair': _imgSofa,
  'ibadan-basket': _imgCaneFurniture,
  'amaka-bag': _imgHandbag,
  'amaka-waist': _imgBeadedJewelry,
  'ngozi-efo': _imgNigerianFood,
  'ngozi-jollof': _imgNigerianFood,
  'ngozi-zobo': _imgZobo,
  'ngozi-chips': _imgPlantainChips,
  'chinedu-tap': _imgFaucet,
  'ibadan-bed': _imgBed,
  'ibadan-kitchen': _imgKitchen,
  'amaka-earrings': _imgBeadedJewelry,
  'amaka-scarf': _imgSilkScarf,
  'spark-socket': _imgElectrician,
  'spark-solar': _imgSolarInstaller,
  'vi-leak': _imgFaucet,
  'vi-tank': _imgPipes,
};

String photoUrl(String seed) {
  final listing = _listingPhotos[seed];
  if (listing != null) return listing;

  for (final entry in _photoSets.entries) {
    if (seed.startsWith('${entry.key}-')) {
      final match = RegExp(r'-(\d+)$').firstMatch(seed);
      final index = match == null ? 0 : (int.parse(match.group(1)!) - 1);
      return entry.value[index % entry.value.length];
    }
  }

  // Fallback for new/demo businesses that do not have a curated set yet.
  const fallback = [_imgTools, _imgNigerianTailor, _imgNigerianCarpenter];
  final match = RegExp(r'-(\d+)$').firstMatch(seed);
  final index = match == null ? 0 : (int.parse(match.group(1)!) - 1);
  return fallback[index % fallback.length];
}

({String name, String photo, String bio}) _ownerProfile(String id) {
  return switch (id) {
    'radiance-tailors' => (
        name: 'Chidinma Okafor',
        photo: 'https://randomuser.me/api/portraits/women/44.jpg',
        bio: 'Founder and lead tailor. Chidinma has been making bridal and '
            'agbada pieces in Ikeja for 11 years.',
      ),
    'mama-nkechi-stitches' => (
        name: 'Nkechi Eze',
        photo: 'https://randomuser.me/api/portraits/women/68.jpg',
        bio: 'Nkechi runs a small family workshop in Surulere. School uniforms '
            'and everyday tailoring are her speciality.',
      ),
    'flowfix-plumbing' => (
        name: 'Emeka Obi',
        photo: 'https://randomuser.me/api/portraits/men/32.jpg',
        bio: 'Emeka is a licensed plumber covering Ikeja and nearby LGAs. He '
            'specialises in leaks, pumps and borehole repairs.',
      ),
    'brightspark-electricals' => (
        name: 'Tunde Adebayo',
        photo: 'https://randomuser.me/api/portraits/men/45.jpg',
        bio: 'Tunde leads a small electrical team. Solar, inverters and '
            'residential wiring are their daily work.',
      ),
    'adebayo-woodworks' => (
        name: 'Segun Adebayo',
        photo: 'https://randomuser.me/api/portraits/men/52.jpg',
        bio: 'Segun builds custom furniture from his workshop in Surulere. '
            'He is known for wardrobes, beds and kitchen cabinets.',
      ),
    'glow-by-tola' => (
        name: 'Tola Adeniyi',
        photo: 'https://randomuser.me/api/portraits/women/65.jpg',
        bio: 'Tola is a bridal makeup artist and hairstylist. She works on '
            'location across Lagos and Oyo.',
      ),
    'lekki-threads' => (
        name: 'Amaka Okafor',
        photo: 'https://randomuser.me/api/portraits/women/79.jpg',
        bio: 'Amaka designs ready-to-wear pieces and accessories from her '
            'Lekki studio.',
      ),
    'chinedu-plumbing' => (
        name: 'Chinedu Nwosu',
        photo: 'https://randomuser.me/api/portraits/men/76.jpg',
        bio: 'Chinedu is a mobile plumber serving Ibadan North and nearby '
            'LGAs. He answers emergency leaks same day.',
      ),
    'ibadan-carpentry-hub' => (
        name: 'Bola Akinola',
        photo: 'https://randomuser.me/api/portraits/men/22.jpg',
        bio: 'Bola makes fitted furniture and doors in Ibadan. He trains '
            'apprentices in the same workshop.',
      ),
    'amakas-accessories' => (
        name: 'Amaka Nwosu',
        photo: 'https://randomuser.me/api/portraits/women/12.jpg',
        bio: 'Amaka makes beaded bags, waist beads and statement jewellery '
            'by hand.',
      ),
    'mama-ngozi-kitchen' => (
        name: 'Ngozi Okeke',
        photo: 'https://randomuser.me/api/portraits/women/56.jpg',
        bio: 'Ngozi cooks from her family kitchen in Aguda. She started with '
            'lunch packs for market traders and now caters small events.',
      ),
    'sparkline-electricals' => (
        name: 'Kelechi Umeh',
        photo: 'https://randomuser.me/api/portraits/men/85.jpg',
        bio: 'Kelechi handles inverter, solar and generator installations '
            'for homes and small shops.',
      ),
    'vi-plumbers' => (
        name: 'Femi Balogun',
        photo: 'https://randomuser.me/api/portraits/men/41.jpg',
        bio: 'Femi is a Victoria Island plumber focused on apartments, '
            'offices and facility maintenance.',
      ),
    _ => (
        name: 'Nijaora business owner',
        photo: 'https://randomuser.me/api/portraits/lego/1.jpg',
        bio: 'This business is owned and run by a Nijaora member.',
      ),
  };
}

Business _business({
  required String id,
  required String name,
  required String description,
  required List<String> categories,
  required String stateId,
  required String lgaId,
  required String baseArea,
  required List<String> photos,
  required List<Listing> listings,
  String? neighbourhoodId,
  OperatingModel operatingModel = OperatingModel.fixedLocation,
  List<String> serves = const [],
  Availability availability = Availability.availableToday,
  int verification = 1,
  double completeness = 0.8,
  int response = 30,
  double rating = 0,
  int reviewCount = 0,
  String? whatsapp,
  String? phone,
  String? hours,
  String? slug,
  int ageDays = 60,
}) {
  final hasProduct = listings.any((l) => l.type == ListingType.product);
  final hasService = listings.any((l) => l.type == ListingType.service);
  final owner = _ownerProfile(id);
  final score = Business.computeLightScore(
    completeness: completeness,
    medianResponseMinutes: response,
    rating: rating,
    reviewCount: reviewCount,
    verificationLevel: verification,
  );

  return Business(
    id: id,
    ownerId: 'owner-$id',
    name: name,
    description: description,
    categoryIds: categories,
    stateId: stateId,
    lgaId: lgaId,
    neighbourhoodId: neighbourhoodId,
    baseArea: baseArea,
    operatingModel: operatingModel,
    serviceAreaLgaIds:
        operatingModel == OperatingModel.mobile ? serves : const [],
    availability: availability,
    verificationLevel: verification,
    lightScore: score,
    completeness: completeness,
    medianResponseMinutes: response,
    rating: rating,
    reviewCount: reviewCount,
    photos: photos,
    listings: listings,
    hasProduct: hasProduct,
    hasService: hasService,
    isPublished: true,
    createdAt: DateTime.now().subtract(Duration(days: ageDays)),
    whatsappNumber: whatsapp,
    phoneNumber: phone,
    openingHours: hours,
    slug: slug,
    ownerName: owner.name,
    ownerPhotoUrl: owner.photo,
    ownerBio: owner.bio,
  );
}

Listing _listing(
  String id,
  String businessId,
  ListingType type,
  String title,
  String description,
  PriceType priceType,
  int? price,
) {
  return Listing(
    id: id,
    businessId: businessId,
    type: type,
    title: title,
    description: description,
    priceType: priceType,
    price: price,
    images: [photoUrl(id)],
    categoryId: _productCategoryFor(id),
  );
}

String? _productCategoryFor(String listingId) {
  const categories = <String, String>{
    'radiance-agbada': 'product-clothing',
    'radiance-bridal': 'product-clothing',
    'radiance-ankara': 'product-clothing',
    'nkechi-gown': 'product-clothing',
    'nkechi-uniform': 'product-clothing',
    'threads-dress': 'product-clothing',
    'threads-set': 'product-clothing',
    'threads-bag': 'product-shoes',
    'threads-scarf': 'product-accessories',
    'threads-tote': 'product-shoes',
    'radiance-jacket': 'product-clothing',
    'radiance-headtie': 'product-accessories',
    'nkechi-ready-gown': 'product-clothing',
    'adebayo-dining': 'product-furniture',
    'adebayo-wardrobe': 'product-furniture',
    'adebayo-desk': 'product-furniture',
    'adebayo-shelf': 'product-decor',
    'glow-touchup': 'product-cosmetics',
    'glow-hair-oil': 'product-haircare',
    'glow-shea': 'product-skincare',
    'ibadan-bed': 'product-furniture',
    'ibadan-chair': 'product-furniture',
    'ibadan-basket': 'product-decor',
    'amaka-earrings': 'product-jewellery',
    'amaka-scarf': 'product-accessories',
    'amaka-bag': 'product-beadwork',
    'amaka-waist': 'product-jewellery',
    'ngozi-efo': 'product-food',
    'ngozi-jollof': 'product-food',
    'ngozi-zobo': 'product-drinks',
    'ngozi-chips': 'product-food',
  };
  return categories[listingId];
}

Review _review(
  String id,
  String businessId,
  String customerName,
  int rating,
  String text,
  DateTime createdAt, {
  String? reply,
}) {
  return Review(
    id: id,
    businessId: businessId,
    customerId: 'customer-$id',
    customerName: customerName,
    rating: rating,
    text: text,
    createdAt: createdAt,
    ownerReply: reply,
  );
}