class CreateImages < ActiveRecord::Migration[8.0]
  def change
    create_table :images do |t|
      t.string :title
      t.string :original_filename
      t.string :pixelated_filename
      t.string :paint_by_number_filename
      t.string :share_token
      t.string :status
      t.integer :width
      t.integer :height
      t.integer :pixel_size
      t.integer :color_count

      t.timestamps
    end
    add_index :images, :share_token
  end
end
