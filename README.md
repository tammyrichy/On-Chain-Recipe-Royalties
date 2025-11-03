# 🍳 On-Chain Recipe Royalties

A decentralized recipe marketplace where chefs can mint their recipes as NFTs, earn royalties from commercial usage, and enable collaborative recipe development with automatic royalty distribution.

## 🌟 Features

### 👨‍🍳 For Chefs
- **Mint Recipe NFTs** - Transform your culinary creations into tradeable digital assets
- **Set Royalty Rates** - Earn up to 50% royalties on every commercial license
- **Enable Forking** - Allow others to build upon your recipes with revenue sharing
- **Track Earnings** - Monitor total earnings and reputation scores in real-time

### 🍽️ For Users
- **Purchase Licenses** - Get commercial or personal usage rights for recipes
- **Rate & Review** - Share feedback and help surface the best recipes
- **Fork Recipes** - Create variations and automatically share royalties with original chefs
- **Browse Trending** - Discover popular recipes based on licenses and ratings

## 📋 Contract Functions

### Core Recipe Management

#### `mint-recipe`
Creates a new recipe NFT with full metadata and pricing structure.

```clarity
(contract-call? .On-Chain-Recipe-Royalties mint-recipe 
    u"Grandma's Chocolate Chip Cookies"
    "Dessert"
    u2              ;; difficulty (1-5)
    u30             ;; prep time in minutes
    u24             ;; servings
    u"flour, butter, sugar, chocolate chips..."
    u"Mix dry ingredients, cream butter..."
    u2000000        ;; license fee (2 STX)
    u20             ;; royalty percentage
    true)           ;; fork allowed
```

#### `purchase-license`
Acquire usage rights for a recipe with automatic royalty distribution.

```clarity
(contract-call? .On-Chain-Recipe-Royalties purchase-license 
    u1              ;; recipe-id
    true)           ;; commercial use (doubles the fee)
```

#### `rate-recipe`
Rate and review recipes to help others discover quality content.

```clarity
(contract-call? .On-Chain-Recipe-Royalties rate-recipe
    u1              ;; recipe-id
    u5              ;; rating (1-5)
    (some u"Amazing recipe! Family loved it"))
```

#### `fork-recipe`
Create variations of existing recipes with automatic royalty splitting.

```clarity
(contract-call? .On-Chain-Recipe-Royalties fork-recipe
    u1              ;; original recipe-id
    u"Vegan Chocolate Chip Cookies"
    u"Replace butter with coconut oil..."
    u30)            ;; royalty split percentage to original chef
```

### Additional Functions

- `update-nutrition-info` - Add nutritional information to your recipes
- `transfer-recipe` - Transfer ownership of recipe NFTs
- `withdraw-platform-fees` - Platform owner can withdraw accumulated fees

## 📊 Read-Only Functions

- `get-recipe` - Get basic recipe information
- `get-recipe-details` - Get full ingredients and instructions
- `get-recipe-stats` - View licenses, ratings, and trending scores
- `get-user-license` - Check if a user has licensed a recipe
- `get-chef-profile` - View chef statistics and reputation
- `get-platform-earnings` - Check total platform fees collected
- `get-recipe-rating` - Get a specific user's rating for a recipe

## 🏗️ Architecture

### Data Structures
- **Recipe NFTs** - Non-fungible tokens representing unique recipes
- **License System** - Tracks commercial and personal usage rights
- **Rating System** - Community-driven quality scoring
- **Fork Tracking** - Maintains relationships between original and derivative recipes
- **Chef Profiles** - Reputation and earnings tracking for content creators

### Economic Model
- **Platform Fee**: 5% of all transactions
- **Max Royalty**: Up to 50% on commercial licenses
- **Commercial Multiplier**: 2x fee for commercial usage
- **Minimum License Fee**: 1 STX

## 💰 Revenue Flows

1. **Direct Sales** - Chefs earn from initial recipe licenses
2. **Royalties** - Ongoing earnings from commercial usage
3. **Fork Revenue** - Shared earnings from recipe derivatives
4. **Platform Fees** - 5% to maintain the ecosystem

## 🚀 Getting Started

1. Deploy the contract using Clarinet
2. Mint your first recipe with appropriate pricing
3. Enable forking to encourage collaborative development
4. Monitor earnings through chef profile queries

## 🛠️ Development

```bash
# Check contract syntax
clarinet check

# Run tests
clarinet test

# Deploy to testnet
clarinet deploy --testnet
```

## 📈 Use Cases

- **Professional Chefs** - Monetize signature recipes
- **Food Bloggers** - Create licensable content libraries
- **Restaurants** - Purchase commercial rights to trending recipes
- **Home Cooks** - Share family recipes and earn passive income
- **Culinary Schools** - Access verified, high-quality recipe databases

## 🔐 Security Features

- Owner-only functions protected
- Input validation on all parameters
- Automatic royalty calculations
- Immutable recipe ownership via NFTs
- Protected fee withdrawals

## 📝 License

This smart contract enables a new paradigm for recipe ownership and monetization on the blockchain.

---

*Built with ❤️ using Clarity and Stacks*

# On-Chain-Recipe-Royalties

