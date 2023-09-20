def tick(args)
  main(
    state: args.state,
    sprites: args.outputs.sprites,
    labels: args.outputs.labels,
    outputs: args.outputs,
    inputs: args.inputs,
    grid: args.grid,
    sounds: args.outputs.sounds
  )
end

def main(state:, sprites:, labels:, outputs:, inputs:, grid:, sounds:)
  state.collision_box ||= {
    x: 0,
    y: 0,
    w: 80,
    h: 20
  }
  state.player ||= {
    x: grid.w / 2 - 65,
    y: -130,
    w: 150,
    h: 130,
    path: "sprites/toasty.png",
    # custom
    speed_x: 12,
    dy: 0,
    box: state.collision_box,
  }
  state.platforms ||= []
  state.world ||= { y: 0, last_platform_wy: -1, last_toasty_score: 0, game_over: false, score: 0 }
  state.toasty_guy ||= {
    x: grid.w,
    y: 0,
    w: 213,
    h: 180,
    path: "sprites/toasty-guy.png"
  }

  if state.world.game_over
    labels << [grid.w / 2, grid.h / 2 + 70, "Game Over", 50, 1, 255, 255, 255]
    labels << [grid.w / 2, grid.h / 2 - 100, "Hit `R` to start over", 20, 1, 255, 255, 255]
    labels << [ 30, 30.from_top, "Score: #{state.world.score}", 0, 0, 255, 255, 255 ]
    outputs.background_color = [0, 0, 0]
  else
    if state.tick_count == 0
      jump(state.player, state.tick_count)
    end

    handle_player_move(state.player, inputs, grid, state.tick_count, state.world)
    handle_player_animation(state.player, state.tick_count)
    handle_platforms(state.player, state.platforms, grid, state.tick_count, state.world)
    handle_camera(grid, state.world, state.player, state.platforms)
    handle_score(state.world)
    handle_toasty(state.toasty_guy, grid, sounds, state.tick_count, state.world)

    sprites << state.platforms
    sprites << state.toasty_guy
    sprites << state.player
    labels << [ 30, 30.from_top, "Score: #{state.world.score}" ]
    outputs.background_color = [172, 117, 16]
  end

  handle_reset(inputs)
end

def update_collision_box(player)
  player.box.x = player.x + (player.w - player.box.w) / 2
  player.box.y = player.y
end

def jump(player, ticks)
  player.jumped_y = player.y
  player.jumped_at = ticks
end

def handle_player_move(player, inputs, grid, ticks, world)
  # horizontal movement
  if inputs.left
    player.x -= player.speed_x
  elsif inputs.right
    player.x += player.speed_x
  end

  player_half_w = player.w / 2
  if player.x < -player_half_w
    player.x = grid.w - player_half_w
  elsif player.x > grid.w - player_half_w
    player.x = -player_half_w
  end

  # veritcal movement
  jump_force = 40
  gravity = 1

  if !$gtk.production? && inputs.keyboard.key_down.space
    jump(player, ticks)
  end

  if player.jumped_at
    jump_time = ticks - player.jumped_at
    new_player_y = (player.jumped_y + jump_force * jump_time - gravity * jump_time ** 2 / 2).to_i

    player.dy = new_player_y - player.y
    player.y = new_player_y
  end

  if player.y < -player.h
    world.game_over = true
  end

  update_collision_box(player)
end

def handle_player_animation(player, ticks)
  if !player.jumped_at.nil? && ticks - player.jumped_at < 30
    player.path = "sprites/toasty-jump.png"
  else
    player.path = "sprites/toasty.png"
  end
end

def handle_platforms(player, platforms, grid, ticks, world)
  max_platforms = 7
  platform_w = 100
  stride_y = 80
  stride_x = 20

  (0..grid.h / stride_y).each do |i|
    norm_y = i * stride_y
    norm_wy = (world.y / stride_y).to_i * stride_y + norm_y
    next if world.last_platform_wy >= norm_wy

    next_platform_x = rand(grid.w)
    max_platforms.times do
      break if next_platform_x > grid.w - platform_w

      platforms << spawn_platform(next_platform_x, norm_y)
      next_platform_x += platform_w + stride_x + rand(grid.w)
    end

    world.last_platform_wy = norm_wy
  end

  platforms.each do |platform|
    if player.dy < 0 && platform.intersect_rect?(player.box)
      player.y = platform.y + platform.h / 2
      jump(player, ticks)
      update_collision_box(player)
    end

    if platform.y < -platform.h
      platform.erased = true
    end
  end

  platforms.reject!(&:erased)
end

def spawn_platform(x, y)
  {
    x: x,
    y: y,
    w: 100,
    h: 40,
    path: "sprites/platform-bacon.png",
    flip_horizontally: rand(3) == 1,
    # custom
    erased: false
  }
end

def handle_camera(grid, world, player, platforms)
  dy = (player.y - grid.h / 2).to_i
  return if dy <= 0

  world.y += dy
  player.y -= dy
  player.jumped_y -= dy
  platforms.each { |platform| platform.y -= dy }

  update_collision_box(player)
end

def handle_score(world)
  world.score = world.y
end

def handle_toasty(toasty_guy, grid, sounds, ticks, world)
  next_toasty_score = world.last_toasty_score + 10000
  if world.score > next_toasty_score && toasty_guy.appeared_at.nil?
    toasty_guy.appeared_at = ticks
    world.last_toasty_score = next_toasty_score
    sounds << "sounds/toasty.ogg"
  end

  if toasty_guy.appeared_at != nil
    elapsed_time = ticks - toasty_guy.appeared_at
    acceleration = 1
    target_x = grid.w - toasty_guy.w + 30

    if toasty_guy.x > target_x
      toasty_guy.x = (grid.w - acceleration * elapsed_time ** 2 / 2).to_i
    end

    if elapsed_time > 60
      toasty_guy.x = grid.w
      toasty_guy.appeared_at = nil
    end
  end
end

def handle_reset(inputs)
  return unless inputs.keyboard.key_down.r

  $gtk.reset_next_tick
end
