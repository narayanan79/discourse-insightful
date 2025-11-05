# Discourse Insightful Plugin

A Discourse plugin that adds an "insightful" button next to the like button, allowing users to mark posts that provide valuable insights or learning moments.

## Features

- **Insightful Button**: Lightbulb-style button with three states:
  - Outline lightbulb (not marked)
  - Solid lightbulb (marked)
  - Colored solid when user has marked as insightful
- **Count Display**: Shows number of users who marked the post as insightful
- **Who Marked**: Click count to see avatars of users who marked as insightful
- **Real-time Updates**: Live updates via MessageBus when others act
- **Rate Limiting**: Configurable daily limits per user
- **Trust Level Control**: Minimum trust level requirements
- **Mobile Responsive**: Works on all screen sizes
- **Accessibility**: Full keyboard navigation and screen reader support

## Installation

1. Clone this repository into your Discourse plugins directory:
   ```bash
   cd plugins
   git clone https://github.com/discourse/discourse-insightful.git
   ```

2. Rebuild Discourse:
   ```bash
   ./launcher rebuild app
   ```

## Configuration

The plugin adds several site settings under Admin > Settings > Plugins:

- **insightful_enabled**: Enable/disable the insightful feature (default: true)
- **insightful_max_per_day**: Maximum insightful actions per user per day (default: 50)
- **insightful_min_trust_level**: Minimum trust level to use insightful (default: 0)
- **insightful_show_who_insightfuled**: Show who marked posts as insightful (default: true)

## Architecture

### Backend Components

- **InsightfulActionCreator**: Service object for creating insightful actions
  - Uses Discourse's Service::Base framework
  - Handles permissions, rate limiting, and validations
  - Event-driven architecture (triggers :post_action_created events)
- **InsightfulActionDestroyer**: Service object for removing insightful actions
  - Validates user permissions before removal
  - Maintains data consistency through event listeners
- **InsightfulDaily**: Model for tracking daily action limits
  - Prevents abuse through per-user daily quotas
  - Automatic cleanup of old records
- **InsightfulController**: API endpoints for insightful operations
  - RESTful design with proper error handling
  - Uses Guardian for authorization
- **Post Action Type**: New post action type (ID: 51) for insightful
  - Integrated with Discourse's existing post action system

### Frontend Components

- **InsightfulButton**: Main button component with animations
  - Glimmer component with full JSDoc documentation
  - Optimistic UI updates for instant feedback
  - MessageBus integration for real-time updates
  - Proper loading and disabled states
- **InsightfulCount**: Count display and user list component
  - Shows insightful count and user avatars
  - Click-to-expand user list with accessibility support
- **Post Menu Integration**: Seamless integration with existing post controls
  - Uses Discourse's post-menu-buttons value transformer
  - Positioned after actionable, before reply, share, and flag buttons
- **Icon System**: Lightbulb icon for insightful actions

### Database Tables

- **insightful_daily**: Tracks daily action counts per user
  - Indexed on user_id and insightful_date for fast queries
  - Unique constraint prevents duplicate entries
- **posts.insightful_count**: Denormalized count for performance
  - Updated via event listeners to avoid N+1 queries
  - Indexed for efficient sorting and filtering
- **post_actions**: Uses existing table with insightful post action type
  - Leverages Discourse's built-in post action infrastructure
- **user_stats**: Extended with insightful_given and insightful_received columns
- **directory_items**: Includes insightful statistics for user directory

## API Endpoints

- `POST /insightful/:post_id` - Mark post as insightful
- `DELETE /insightful/:post_id` - Remove insightful from post
- `GET /insightful/:post_id/who` - Get users who marked the post as insightful

## Events

The plugin triggers Discourse events that other plugins can listen to:

- `insightful_created` - When a post is marked as insightful
- `insightful_destroyed` - When insightful is removed from a post

## Styling

The plugin includes comprehensive CSS with support for:

- Dark mode
- High contrast mode
- Mobile responsive design
- Animation effects
- Accessibility focus styles

## Code Quality

This plugin follows Discourse best practices and coding standards:

- ✅ **Zero RuboCop offenses** - All Ruby code passes strict linting
- ✅ **Service-based architecture** - Uses Discourse's Service::Base framework
- ✅ **Event-driven design** - Single source of truth via event listeners
- ✅ **Performance optimized** - Denormalized counts, indexed queries, no N+1 issues
- ✅ **Security hardened** - Guardian integration, rate limiting, input validation
- ✅ **Accessibility compliant** - ARIA labels, keyboard navigation support

## Testing

Run the plugin tests:

```bash
bundle exec rspec plugins/discourse-insightful/spec
```

The plugin includes comprehensive test coverage:
- Service object specs (InsightfulActionCreator, InsightfulActionDestroyer)
- Controller specs with error handling
- Model specs for InsightfulDaily
- System specs for UI interactions
- Integration tests for real-time updates

## License

MIT License - see LICENSE file for details.

## Development

### Starting the Development Environment

```bash
# Start Rails server
RAILS_ENV=development bin/rails server -p 3000 -b 0.0.0.0

# Start Ember server (in another terminal)
pnpm ember s --proxy http://localhost:3000
```

Access the application at http://localhost:4200

### Code Style

This plugin follows Discourse coding standards:
- Run `bundle exec rubocop -A` to auto-fix Ruby linting issues
- Add JSDoc comments to all JavaScript classes, methods, and getters
- Follow the service object pattern for business logic
- Use event listeners in plugin.rb for cross-cutting concerns

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Ensure all tests pass and code is linted
6. Submit a pull request

### Pull Request Checklist

- [ ] All RuboCop offenses resolved (`bundle exec rubocop`)
- [ ] JSDoc comments added for new JavaScript code
- [ ] Tests added and passing (`bundle exec rspec`)
- [ ] No console.log or debug statements in production code
- [ ] README updated if adding new features

## Companion Plugin

This plugin works great alongside the **discourse-actionable** plugin, which allows users to mark posts as requiring action. Together, they provide a comprehensive system for community-driven content curation.
